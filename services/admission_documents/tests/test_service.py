import concurrent.futures
from io import BytesIO
import json
from pathlib import Path
import tempfile
import threading
import unittest

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from PIL import Image
from services.admission_documents.adapters import LocalPrivateArchive
from services.admission_documents.service import Entitlements, Denied, canonical, measure_image, CAPABILITY

SCHOOL='22222222-2222-4222-8222-222222222222'
KEY='admissions/'+SCHOOL+'/88888888-8888-4888-8888-888888888888'


def image_bytes(format='PNG'):
    out=BytesIO(); Image.new('RGB',(8,8),(40,80,120)).save(out,format=format); return out.getvalue()


class StorageBoundaries(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.directory=Path(self.temp.name)
        self.key=Ed25519PrivateKey.generate(); self.clock=[1000]
        self.audits=[]
        self.kw=dict(school_id=SCHOOL,issuer='test-control-plane',keys={'test':self.key.public_key().public_bytes(Encoding.Raw,PublicFormat.Raw)},maximum_age=60,maximum_ttl=120,audit=lambda *x:self.audits.append(x),clock=lambda:self.clock[0])
        self.ent=Entitlements(self.directory/'state.sqlite',**self.kw)

    def tearDown(self): self.temp.cleanup()

    def snapshot(self,**overrides):
        p=dict(schema_version=1,issuer='test-control-plane',audience=SCHOOL,revision=1,subscription_state='ACTIVE',issued_at=990,effective_at=990,expires_at=1100,capabilities={CAPABILITY:True},modules={'admissions':True});p.update(overrides)
        raw=canonical(p);return raw,'test',self.key.sign(raw)

    def test_missing_snapshot_denies(self):
        with self.assertRaises(Denied),self.ent.current(): pass
    def test_signed_current_snapshot_and_audit(self):
        self.ent.activate(*self.snapshot())
        with self.ent.current() as (revision,digest,valid_until): self.assertEqual((revision,len(digest)),(1,32))
        self.assertEqual(len(self.audits),1)
    def test_bad_signature(self):
        raw,k,sig=self.snapshot()
        with self.assertRaises(Denied): self.ent.activate(raw,k,bytes(64))
    def test_wrong_school(self):
        with self.assertRaises(Denied): self.ent.activate(*self.snapshot(audience='33333333-3333-4333-8333-333333333333'))
    def test_unknown_key(self):
        raw,k,sig=self.snapshot()
        with self.assertRaises(Denied): self.ent.activate(raw,'unknown',sig)
    def test_wrong_issuer(self):
        with self.assertRaises(Denied): self.ent.activate(*self.snapshot(issuer='untrusted'))
    def test_expired_snapshot(self):
        with self.assertRaises(Denied): self.ent.activate(*self.snapshot(expires_at=1000))
    def test_future_effective(self):
        with self.assertRaises(Denied): self.ent.activate(*self.snapshot(effective_at=1001))
    def test_string_boolean_not_capability(self):
        with self.assertRaises(Denied): self.ent.activate(*self.snapshot(capabilities={CAPABILITY:'true'}))
    def test_finite_ttl_required(self):
        with self.assertRaises(Denied): self.ent.activate(*self.snapshot(expires_at=float('inf')))
    def test_oversize_ttl(self):
        with self.assertRaises(Denied): self.ent.activate(*self.snapshot(expires_at=5000))
    def test_stale_cache_closes(self):
        self.ent.activate(*self.snapshot());self.clock[0]=1051
        with self.assertRaises(Denied),self.ent.current(): pass
    def test_monotonic_revision_survives_restart(self):
        self.ent.activate(*self.snapshot(revision=2));other=Entitlements(self.directory/'state.sqlite',**self.kw)
        with self.assertRaises(Denied): other.activate(*self.snapshot())
    def test_conflicting_same_revision(self):
        self.ent.activate(*self.snapshot())
        with self.assertRaises(Denied): self.ent.activate(*self.snapshot(capabilities={CAPABILITY:False}))
    def test_downgrade_blocks_new_use(self):
        self.ent.activate(*self.snapshot());self.ent.activate(*self.snapshot(revision=2,capabilities={CAPABILITY:False}))
        with self.assertRaises(Denied),self.ent.current(): pass
    def test_disabled_module_blocks(self):
        self.ent.activate(*self.snapshot(modules={'admissions':False}))
        with self.assertRaises(Denied),self.ent.current(): pass
    def test_suspension_blocks(self):
        self.ent.activate(*self.snapshot(subscription_state='SUSPENDED'))
        with self.assertRaises(Denied),self.ent.current(): pass
    def test_failed_activation_audit_stays_closed(self):
        self.ent.audit=lambda *x:(_ for _ in ()).throw(RuntimeError('audit failure'))
        with self.assertRaises(RuntimeError): self.ent.activate(*self.snapshot())
        with self.assertRaises(Denied),self.ent.current(): pass
    def test_failed_downgrade_audit_cannot_restore_old_enabled_cache(self):
        self.ent.activate(*self.snapshot())
        self.ent.audit=lambda *x:(_ for _ in ()).throw(RuntimeError('audit failure'))
        with self.assertRaises(RuntimeError): self.ent.activate(*self.snapshot(revision=2,capabilities={CAPABILITY:False}))
        other=Entitlements(self.directory/'state.sqlite',**self.kw)
        with self.assertRaises(Denied),other.current(): pass
        with self.assertRaises(Denied): other.activate(*self.snapshot())
        other.activate(*self.snapshot(revision=3))
        with other.current() as (revision,digest,valid_until): self.assertEqual(revision,3)

    def test_two_instances_serialize_finalization_and_revision(self):
        self.ent.activate(*self.snapshot());other=Entitlements(self.directory/'state.sqlite',**self.kw)
        began=threading.Event()
        def activate(): began.set();other.activate(*self.snapshot(revision=2,capabilities={CAPABILITY:False}))
        with concurrent.futures.ThreadPoolExecutor() as pool:
            with self.ent.current():
                future=pool.submit(activate);self.assertTrue(began.wait(2));self.assertFalse(future.done())
            future.result(5)
        with self.assertRaises(Denied),self.ent.current(): pass
    def test_measures_png_and_jpeg(self):
        self.assertEqual(measure_image(image_bytes())[0],'image/png');self.assertEqual(measure_image(image_bytes('JPEG'))[0],'image/jpeg')
    def test_rejects_invalid_and_oversize_images(self):
        for data in (b'',b'%PDF-1.7 spoof',image_bytes()[:15],bytes(1048577)):
            with self.assertRaises(Denied): measure_image(data)
    def test_private_write_once_archive_and_same_bytes_retry(self):
        adapter=LocalPrivateArchive(self.directory/'objects');data=image_bytes();adapter.put_once(KEY,data);adapter.put_once(KEY,data)
        self.assertEqual(adapter.read(KEY,1048576),data)
        self.assertEqual((self.directory/'objects').stat().st_mode&0o777,0o700)
        self.assertEqual(next((self.directory/'objects').iterdir()).stat().st_mode&0o777,0o400)
    def test_archive_cannot_overwrite_or_escape(self):
        adapter=LocalPrivateArchive(self.directory/'objects');adapter.put_once(KEY,image_bytes())
        with self.assertRaises(Denied): adapter.put_once(KEY,image_bytes('JPEG'))
        with self.assertRaises(Denied): adapter.put_once('../../public',image_bytes())
    def test_archive_bounded_reads(self):
        adapter=LocalPrivateArchive(self.directory/'objects');adapter.put_once(KEY,image_bytes())
        with self.assertRaises(Denied): adapter.read(KEY,5)

if __name__=='__main__': unittest.main()
