"""Private response boundary, with DB authority exercised in real CI separately."""
from io import BytesIO
import hashlib
from types import SimpleNamespace
import time
import unittest
from PIL import Image
from services.admission_documents.service import AdmissionDocumentService, VerifiedClaims, Denied


class PrivateReadBoundary(unittest.TestCase):
    def setUp(self):
        output=BytesIO();Image.new('RGB',(4,4)).save(output,format='PNG');self.data=output.getvalue()
        self.calls=[];self.gates=[]
        self.descriptor=dict(school_id='school',storage_location_key='private',object_key='server-key',content_type='image/png',byte_size=len(self.data),content_hash=hashlib.sha256(self.data).hexdigest(),authority_hash='ab'*32,application_version=4,file_version=3)
        archive=SimpleNamespace(read=lambda key,maximum:self.data)
        self.service=AdmissionDocumentService(connect=lambda:None,authenticate=lambda token:VerifiedClaims('11111111-1111-4111-8111-111111111111',int(time.time())-1,int(time.time())+300),entitlements=SimpleNamespace(school='school'),locations={'private':archive},upload_location='private',intent_lifetime=60,read_gate=lambda school:(self.gates.append(school) or True))
        def rpc(claims,sql,params):
            self.calls.append((sql,params))
            return self.descriptor if 'describe' in sql else {'source_id':'proof'}
        self.service._rpc=rpc
    def read(self):return self.service.read_certificate('verified-token',forward_id='forward',link_id='link')
    def test_original_bytes_and_no_private_data_in_representation(self):
        result=self.read();self.assertEqual(result.data,self.data);self.assertEqual(result.access_id,'proof')
        self.assertNotIn('server-key',repr(result));self.assertNotIn('PNG',repr(result));self.assertEqual(len(self.gates),3)
    def test_missing_read_policy_denies_before_database_or_storage(self):
        self.service.read_gate=None
        with self.assertRaises(Denied):self.read()
        self.assertEqual(self.calls,[])
    def test_account_read_policy_rechecked_after_io(self):
        def gate(school):
            self.gates.append(school)
            if len(self.gates)==2:raise Denied('account read policy')
            return True
        self.service.read_gate=gate
        with self.assertRaises(Denied):self.read()
        self.assertEqual(len(self.calls),1)
    def test_byte_corruption_cannot_confirm_read(self):
        self.descriptor['content_hash']='00'*32
        with self.assertRaises(Denied):self.read()
        self.assertEqual(len(self.calls),1)
    def test_wrong_school_cannot_read_bytes(self):
        self.descriptor['school_id']='other'
        with self.assertRaises(Denied):self.read()
        self.assertEqual(len(self.calls),1)
    def test_authentication_adapter_cannot_return_unverified_dictionary(self):
        self.service.authenticate=lambda token:{'sub':'forged'}
        with self.assertRaises(Denied):self.read()
        self.assertEqual(self.calls,[])
    def test_confirm_rechecks_observed_root_file_and_authority(self):
        self.read();params=self.calls[1][1]
        self.assertEqual(params,('forward','link',4,3,bytes.fromhex('ab'*32)))
