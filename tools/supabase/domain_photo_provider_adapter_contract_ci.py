"""Disposable local reference contract for a future server-side file adapter.

NO production endpoints, SDK, credentials, image validation, DB file_objects
writes, provider network, signed URLs or Photo SET. The mock holds synthetic
opaque test bytes so read-back integrity and write-once behavior can be tested.
Policy boolean inputs represent a *trusted test fixture*, never client claims.
"""
from __future__ import annotations

from dataclasses import dataclass, replace
from hashlib import sha256
import hmac
import json
from uuid import UUID, uuid4


MIN_BYTES=1
MAX_BYTES=1_048_576
PURPOSE="STUDENT_PROFILE_PHOTO"
CLASSIFICATION="PRIVATE"
TRIAL_LOCATION="TRIAL_PRIVATE"  # Not a deployed allowlist code.
TRIAL_SECRET=b"DISPOSABLE_TEST_KEY_MUST_NOT_BE_USED_IN_PRODUCTION"


class Denied(Exception):
    """Fail closed without disclosing private storage details."""


class AckLost(Exception):
    """Test-only: provider committed an immutable object, reply was lost."""


def _deny():
    raise Denied("PHOTO_ADAPTER_TRIAL_DENIED")


def _check(predicate,code):
    if predicate is not True:
        raise RuntimeError("D1_PHOTO_PROVIDER_ADAPTER_"+code)


def _must_deny(callback):
    try:
        callback()
    except Denied:
        return
    raise RuntimeError("PHOTO_ADAPTER_TRIAL_FAIL_OPEN")


def _uuid(value):
    try:
        result=UUID(value)
    except (ValueError,TypeError,AttributeError):
        _deny()
    if not isinstance(value,str) or str(result)!=value or result.version!=4:
        _deny()
    return value


@dataclass(frozen=True)
class TrustedTestContext:
    school_id: str
    student_id: str
    campus_id: str
    principal_id: str
    authenticated: bool = True
    permission: bool = True
    scope: bool = True
    current_primary: bool = True
    module_enabled: bool = True
    entitlement_fresh: bool = True
    purpose_enabled: bool = True
    file_upload: bool = True

    def validate(self):
        for value in (self.school_id,self.student_id,self.campus_id,
                      self.principal_id):
            _uuid(value)
        if not all(type(getattr(self,name)) is bool and getattr(self,name)
                   for name in ("authenticated","permission","scope",
                                "current_primary","module_enabled",
                                "entitlement_fresh","purpose_enabled",
                                "file_upload")):
            _deny()


@dataclass(frozen=True)
class TrialIntent:
    intent_id: str
    file_id: str
    school_id: str
    student_id: str
    campus_id: str
    principal_id: str
    purpose: str
    classification: str
    location: str
    object_key: str
    expiry: int


@dataclass(frozen=True)
class VerifiedTrialEvidence:
    intent_id: str
    file_id: str
    location: str
    object_key: str
    byte_size: int
    sha256_hex: str
    receipt: str


@dataclass
class _Stored:
    intent_id: str
    payload: bytes
    key: bytes
    state: str


class LocalPrivateByteProvider:
    """Fake provider with immutable bytes and deliberately misleading HEAD.

    This is not a storage SDK. Its in-memory data is destroyed with process.
    """

    def __init__(self):
        self._objects={}

    def write_once(self,location,key,*,intent_id,payload,idempotency_key,
                   lose_ack=False):
        if (location!=TRIAL_LOCATION or not isinstance(key,str)
                or not isinstance(payload,bytes)
                or type(idempotency_key) is not bytes
                or len(idempotency_key)!=32):
            _deny()
        object_id=(location,key)
        found=self._objects.get(object_id)
        if found is None:
            self._objects[object_id]=_Stored(
                intent_id,payload,idempotency_key,"STAGED")
        elif (found.intent_id!=intent_id or
              not hmac.compare_digest(found.key,idempotency_key) or
              found.payload!=payload or found.state!="STAGED"):
            _deny()
        if lose_ack:
            raise AckLost("DISPOSABLE_PROVIDER_COMMITTED_BEFORE_ACK")
        return True

    def head(self,location,key):
        obj=self._objects.get((location,key))
        if obj is None or obj.state not in ("STAGED","SEALED_TRIAL"):
            _deny()
        # Metadata is *untrusted* without reading back actual stored bytes.
        return {"reported_length":len(obj.payload),"etag":"NOT_A_SHA256"}

    def read_back_for_validation(self,location,key):
        obj=self._objects.get((location,key))
        if obj is None or obj.state not in ("STAGED","SEALED_TRIAL"):
            _deny()
        return obj.payload

    def seal_trial(self,location,key):
        obj=self._objects.get((location,key))
        if obj is None or obj.state!="STAGED":
            _deny()
        obj.state="SEALED_TRIAL"

    def tamper_bytes_for_test(self,location,key,payload):
        """Privileged malicious-provider fixture only."""
        self._objects[(location,key)].payload=payload

    def quarantine(self,location,key):
        obj=self._objects.get((location,key))
        if obj is None:
            return
        obj.state="QUARANTINED"

    def state(self,location,key):
        obj=self._objects.get((location,key))
        return None if obj is None else obj.state


class LocalAdapterContractTrial:
    """Private server-only choreography with injected current authorization.

    The synthetic 'validator' must be a trusted test callback; it is NOT
    evidence of image decoding, content sanitization, malware scanning or
    real authorization, and cannot activate Student Photo uploads.
    """

    def __init__(self,*,provider,school_id,now,validator,server_key):
        if (type(provider) is not LocalPrivateByteProvider
                or not callable(now) or not callable(validator)
                or type(server_key) is not bytes or len(server_key)<32):
            _deny()
        self.school_id=_uuid(school_id)
        self.provider=provider
        self.now=now
        self.validator=validator
        self.server_key=server_key
        self.intents={}
        self.evidence={}
        self.alerts=[]

    def _active(self,ctx,intent=None):
        if type(ctx) is not TrustedTestContext:
            _deny()
        ctx.validate()
        if ctx.school_id!=self.school_id:
            _deny()
        if intent is not None:
            if (ctx.student_id!=intent.student_id or
                ctx.campus_id!=intent.campus_id or
                ctx.principal_id!=intent.principal_id or
                ctx.school_id!=intent.school_id or
                self.now()>=intent.expiry):
                _deny()

    def allocate(self,ctx,*,ttl):
        self._active(ctx)
        if type(ttl) is not int or ttl<=0 or ttl>3600:
            _deny()  # Reference harness ceiling, NOT an approved product TTL.
        if type(self.now()) is not int:
            _deny()
        intent_id=str(uuid4())
        file_id=str(uuid4())
        intent=TrialIntent(
            intent_id,file_id,ctx.school_id,ctx.student_id,
            ctx.campus_id,ctx.principal_id,PURPOSE,CLASSIFICATION,
            TRIAL_LOCATION,
            f"school/{ctx.school_id}/student-photo-trial/{file_id}",
            self.now()+ttl)
        self.intents[intent_id]=intent
        # No file_objects row exists at intent allocation time.
        return intent

    def _intent(self,ctx,intent):
        if (type(intent) is not TrialIntent or
            self.intents.get(intent.intent_id)!=intent):
            _deny()
        self._active(ctx,intent)

    def _key(self,intent):
        return sha256(
            b"EDUSYNC_DISPOSABLE_PUT_V1:"+
            UUID(intent.intent_id).bytes+UUID(intent.file_id).bytes+
            UUID(intent.school_id).bytes
        ).digest()

    def put(self,ctx,intent,*,payload,lose_ack=False):
        self._intent(ctx,intent)
        if (type(lose_ack) is not bool or type(payload) is not bytes or
            not (MIN_BYTES<=len(payload)<=MAX_BYTES)):
            _deny()
        # Private staging only. No content classification/Photo SET from PUT.
        return self.provider.write_once(
            intent.location,intent.object_key,intent_id=intent.intent_id,
            payload=payload,idempotency_key=self._key(intent),
            lose_ack=lose_ack)

    def _sign(self,data):
        payload=json.dumps(data,sort_keys=True,separators=(",",":")).encode()
        return hmac.new(self.server_key,payload,"sha256").hexdigest()

    def inspect_trial(self,ctx,intent,*,expected_sha256):
        self._intent(ctx,intent)
        if (type(expected_sha256) is not str or len(expected_sha256)!=64 or
            any(c not in "0123456789abcdef" for c in expected_sha256)):
            _deny()
        if intent.intent_id in self.evidence:
            previous=self.evidence[intent.intent_id]
            if previous.sha256_hex!=expected_sha256:
                _deny()
            payload=self.provider.read_back_for_validation(
                intent.location,intent.object_key)
            if sha256(payload).hexdigest()!=previous.sha256_hex or (
                    len(payload)!=previous.byte_size):
                _deny()
            return previous
        # Provider HEAD/ETag alone cannot prove integrity.
        self.provider.head(intent.location,intent.object_key)
        payload=self.provider.read_back_for_validation(
            intent.location,intent.object_key)
        actual=sha256(payload).hexdigest()
        if (not (MIN_BYTES<=len(payload)<=MAX_BYTES)
                or actual!=expected_sha256
                or self.validator(payload) is not True):
            _deny()
        data={"v":1,"school":intent.school_id,"student":intent.student_id,
              "campus":intent.campus_id,"file":intent.file_id,
              "intent":intent.intent_id,"location":intent.location,
              "object_key":intent.object_key,"bytes":len(payload),
              "sha256":actual,"purpose":intent.purpose,
              "classification":intent.classification}
        evidence=VerifiedTrialEvidence(
            intent.intent_id,intent.file_id,intent.location,
            intent.object_key,len(payload),actual,self._sign(data))
        # Local trial seal forbids any further PUT, including same bytes.
        self.provider.seal_trial(intent.location,intent.object_key)
        self.evidence[intent.intent_id]=evidence
        return evidence

    def verify_receipt(self,intent,evidence):
        if (type(intent) is not TrialIntent or
                type(evidence) is not VerifiedTrialEvidence or
                self.intents.get(intent.intent_id)!=intent or
                evidence.intent_id!=intent.intent_id or
                evidence.file_id!=intent.file_id or
                evidence.object_key!=intent.object_key or
                evidence.location!=intent.location):
            _deny()
        data={"v":1,"school":intent.school_id,"student":intent.student_id,
              "campus":intent.campus_id,"file":intent.file_id,
              "intent":intent.intent_id,"location":intent.location,
              "object_key":intent.object_key,"bytes":evidence.byte_size,
              "sha256":evidence.sha256_hex,"purpose":intent.purpose,
              "classification":intent.classification}
        if not hmac.compare_digest(self._sign(data),evidence.receipt):
            _deny()
        return True

    def quarantine(self,intent,*,reason):
        """Only privileged local reconciliation; no remote deletion."""
        if type(intent) is not TrialIntent or (
                self.intents.get(intent.intent_id)!=intent):
            _deny()
        if reason not in ("EXPIRED","CONTENT_MISMATCH","AUTH_REVOKED",
                          "RETRY_EXHAUSTED"):
            _deny()
        self.provider.quarantine(intent.location,intent.object_key)
        self.alerts.append((intent.intent_id,reason))

    def bounded_reconcile(self,ctx,intent,*,attempt,max_attempts):
        """Retry budget is test-injected; product timing and alerts TBD."""
        if (type(attempt) is not int or type(max_attempts) is not int
                or not (1<=attempt<=max_attempts<=10)):
            _deny()
        try:
            self._intent(ctx,intent)
        except Denied:
            self.quarantine(intent,reason="AUTH_REVOKED")
            return "QUARANTINED"
        if attempt==max_attempts:
            self.quarantine(intent,reason="RETRY_EXHAUSTED")
            return "ALERT"
        return "RETRY_LATER"


def run_photo_provider_adapter_contract_trial():
    """Integration marker for local contract; NOT a hosted provider test."""
    school=str(uuid4()); student=str(uuid4());campus=str(uuid4())
    actor=str(uuid4());clock=[100]
    ctx=TrustedTestContext(school,student,campus,actor)
    adapter=LocalAdapterContractTrial(
        provider=LocalPrivateByteProvider(),school_id=school,
        now=lambda:clock[0],
        validator=lambda data:data.startswith(b"OPAQUE-TEST-"),
        server_key=TRIAL_SECRET)
    intent=adapter.allocate(ctx,ttl=60)
    payload=b"OPAQUE-TEST-ONLY-NOT-AN-IMAGE"
    digest=sha256(payload).hexdigest()
    try:
        adapter.put(ctx,intent,payload=payload,lose_ack=True)
    except AckLost:
        pass
    else:
        raise RuntimeError("PHOTO_ADAPTER_ACK_NOT_LOST")
    _check(adapter.put(ctx,intent,payload=payload),"ADAPTER_RETRY_MISMATCH")
    proof=adapter.inspect_trial(ctx,intent,expected_sha256=digest)
    _check(adapter.verify_receipt(intent,proof),"ADAPTER_RECEIPT_FAILURE")
    _must_deny(lambda:adapter.put(ctx,intent,payload=payload+b"CHANGED"))
    _must_deny(lambda:adapter.inspect_trial(
        replace(ctx,entitlement_fresh=False),intent,expected_sha256=digest))
    _must_deny(lambda:adapter.verify_receipt(
        intent,replace(proof,byte_size=proof.byte_size+1)))
    adapter.provider.tamper_bytes_for_test(
        intent.location,intent.object_key,b"OPAQUE-TEST-TAMPERED")
    _must_deny(lambda:adapter.inspect_trial(ctx,intent,expected_sha256=digest))
    adapter.quarantine(intent,reason="CONTENT_MISMATCH")
    _must_deny(lambda:adapter.provider.read_back_for_validation(
        intent.location,intent.object_key))
    print("D1_STUDENT_PHOTO_PROVIDER_ADAPTER_CONTRACT_PASS "
          "server-allocated private test key, committed-but-lost PUT response, "
          "deterministic write-once retry, read-back measured bytes/hash, "
          "scoped signed test attestation, tamper and revoked-entitlement denial, "
          "metadata quarantine; NO actual image, provider SDK or Photo SET")
