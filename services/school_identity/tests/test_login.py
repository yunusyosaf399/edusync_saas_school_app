import base64
import io
import json
import sys
import time
import unittest
from dataclasses import replace
from pathlib import Path
from unittest.mock import Mock
from uuid import UUID

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from services.school_identity.login import (
    AuthSession, LoginDenied, LoginTarget, SchoolLogin, SupabasePasswordAuth,
    normalize_identifier,
)

SCHOOL = UUID('22222222-2222-4222-8222-222222222222')
USER = UUID('33333333-3333-4333-8333-333333333333')
PRINCIPAL = UUID('44444444-4444-4444-8444-444444444444')
TARGET = LoginTarget(PRINCIPAL, USER, 'FAMILY', None, 1, 1, 100, 1)
EMAIL = 'private@example.invalid'
SESSION = AuthSession(USER, 101, 'ACCESS_SECRET', 'REFRESH_SECRET', 3600)


class LoginTests(unittest.TestCase):
    def setUp(self):
        self.store = Mock()
        self.store.admit.return_value = True
        self.store.resolve.return_value = TARGET
        self.auth = Mock()
        self.auth.authenticate.return_value = SESSION
        self.auth.email_for_subject.return_value = EMAIL
        self.login = SchoolLogin(SCHOOL, self.store, self.auth, b'x'*32)

    def call(self, name=' Parent.One ', password='PASSWORD_SECRET', source='trusted-ingress'):
        return self.login.sign_in(name, password, trusted_source=source)

    def test_alias_and_email_normalization(self):
        self.assertEqual(normalize_identifier(' Parent.One '), ('ALIAS', 'parent.one'))
        self.assertEqual(normalize_identifier(' USER@Example.Invalid '), ('EMAIL', 'user@example.invalid'))

    def test_invalid_identifiers(self):
        for value in (None, '', 'aa', '1abc', 'a'*33, 'user@@example.com', 'u@host',
                      '\tparent', 'parent\n', 'üser', 'u@host\n.invalid', 'x'*255):
            with self.subTest(value=value), self.assertRaises(LoginDenied):
                normalize_identifier(value)

    def test_success_returns_session_without_lookup_data(self):
        result = self.call()
        self.assertEqual(result.principal_id, PRINCIPAL)
        self.assertEqual(result.principal_kind, 'FAMILY')
        self.assertFalse(hasattr(result, 'email'))
        self.assertFalse(hasattr(result, 'person_id'))
        self.assertFalse(hasattr(result, 'binding_version'))
        self.auth.authenticate.assert_called_once_with(EMAIL, 'PASSWORD_SECRET')
        self.assertEqual(self.store.resolve.call_count, 2)

    def test_repr_does_not_expose_secrets_or_private_mapping(self):
        for value in (TARGET, SESSION, self.call()):
            for secret in ('private@example.invalid', 'ACCESS_SECRET', 'REFRESH_SECRET'):
                self.assertNotIn(secret, repr(value))

    def test_rate_limit_before_lookup(self):
        self.store.admit.return_value = False
        with self.assertRaises(LoginDenied): self.call()
        self.store.resolve.assert_not_called()
        self.auth.authenticate.assert_not_called()

    def test_per_account_rate_limit_before_auth(self):
        self.store.admit.side_effect = [True, False]
        with self.assertRaises(LoginDenied): self.call()
        self.auth.authenticate.assert_not_called()

    def test_limit_keys_never_store_identifier_source_or_auth_id(self):
        self.call()
        keys = [key for call in self.store.admit.call_args_list for key in call.args[0]]
        self.assertEqual(len(keys), 3)
        for key in keys: self.assertRegex(key, r'^[0-9a-f]{64}$')
        self.assertEqual(len(set(keys)), 3)

    def test_unknown_user_uses_auth_path_but_cannot_sign_in(self):
        self.store.resolve.return_value = None
        with self.assertRaisesRegex(LoginDenied, '^Unable to sign in$'): self.call()
        self.auth.authenticate.assert_called_once_with('unprovisioned@example.invalid', 'PASSWORD_SECRET')

    def test_provider_failure_is_uniform_and_unchained(self):
        self.auth.authenticate.side_effect = RuntimeError('PASSWORD_SECRET private@example.invalid')
        with self.assertRaises(LoginDenied) as error: self.call()
        self.assertEqual(str(error.exception), 'Unable to sign in')
        self.assertIsNone(error.exception.__cause__)
        self.assertTrue(error.exception.__suppress_context__)

    def test_database_failure_denies_without_auth(self):
        self.store.resolve.side_effect = RuntimeError('DSN_SECRET')
        with self.assertRaises(LoginDenied): self.call()
        self.auth.authenticate.assert_not_called()

    def test_suspension_during_password_check(self):
        self.store.resolve.side_effect = [TARGET, None]
        with self.assertRaises(LoginDenied): self.call()

    def test_changed_binding_alias_principal_or_auth_email_denies(self):
        for changed in (replace(TARGET, binding_version=2), replace(TARGET, alias_version=2),
                        replace(TARGET, principal_version=2), replace(TARGET, auth_user_id=SCHOOL)):
            self.store.resolve.side_effect = [TARGET, changed]
            with self.subTest(changed=changed), self.assertRaises(LoginDenied): self.call()

    def test_auth_subject_mismatch_denies(self):
        self.auth.authenticate.return_value = replace(SESSION, auth_user_id=SCHOOL)
        with self.assertRaises(LoginDenied): self.call()

    def test_pre_recovery_token_denies(self):
        self.auth.authenticate.return_value = replace(SESSION, issued_at=99)
        with self.assertRaises(LoginDenied): self.call()

    def test_exact_token_fence_is_valid(self):
        self.auth.authenticate.return_value = replace(SESSION, issued_at=100)
        self.assertEqual(self.call().principal_id, PRINCIPAL)

    def test_email_authenticates_before_subject_mapping(self):
        result = self.call('USER@EXAMPLE.INVALID')
        self.assertEqual(result.principal_id, PRINCIPAL)
        self.auth.email_for_subject.assert_not_called()
        self.auth.authenticate.assert_called_once_with('user@example.invalid', 'PASSWORD_SECRET')
        self.store.resolve.assert_called_with(SCHOOL, 'SUBJECT', str(USER))

    def test_valid_auth_email_without_school_binding_denies(self):
        self.store.resolve.return_value = None
        with self.assertRaises(LoginDenied): self.call('user@example.invalid')

    def test_email_binding_changed_after_auth_denies(self):
        self.store.resolve.side_effect = [TARGET, replace(TARGET,binding_version=2)]
        with self.assertRaises(LoginDenied): self.call('user@example.invalid')

    def test_untrusted_inputs_fail_closed(self):
        for password, source in (('', 'source'), (None, 'source'), ('p'*4097, 'source'), ('pw', ''), ('pw', None)):
            with self.subTest(password=password, source=source), self.assertRaises(LoginDenied):
                self.call(password=password, source=source)

    def test_configuration_requires_school_uuid_and_strong_secret(self):
        for school, secret in ((str(SCHOOL), b'x'*32), (SCHOOL, b'weak'), (SCHOOL, 'x'*32)):
            with self.assertRaises(ValueError): SchoolLogin(school, self.store, self.auth, secret)


class AuthTransportTests(unittest.TestCase):
    def test_deployment_urls_cannot_redirect_or_contain_credentials(self):
        for url in ('http://example.com', 'https://user:secret@example.com', 'https://example.com/evil',
                    'https://example.com?token=x', 'https://example.com#x', 'https://example.com:123'):
            with self.subTest(url=url), self.assertRaises(ValueError): SupabasePasswordAuth(url, 'key')
        SupabasePasswordAuth('https://school.supabase.co', 'public-key')
        SupabasePasswordAuth('http://127.0.0.1:54321', 'test-key', local_test=True)

    def token(self, **overrides):
        claims = {'sub': str(USER), 'iat': int(time.time()), 'role': 'authenticated',
                  'session_id': str(PRINCIPAL), 'is_anonymous': False}
        claims.update(overrides)
        payload = base64.urlsafe_b64encode(json.dumps(claims).encode()).decode().rstrip('=')
        return 'header.'+payload+'.signature'

    def test_token_is_verified_remotely_before_claims_are_used(self):
        auth = SupabasePasswordAuth('https://school.supabase.co', 'key')
        token = self.token()
        auth._request = Mock(side_effect=[{'access_token': token, 'refresh_token': 'refresh', 'expires_in':3600},
                                          {'id':str(USER)}])
        self.assertEqual(auth.authenticate('user@example.invalid', 'password').auth_user_id, USER)
        self.assertEqual(auth._request.call_args_list[1].args, ('GET', '/user'))
        self.assertEqual(auth._request.call_args_list[1].kwargs, {'token':token})

    def test_unverified_bad_or_anonymous_token_denies(self):
        for claims in ({'sub':str(SCHOOL)}, {'iat':True}, {'iat':int(time.time())+120},
                       {'is_anonymous':True}, {'role':'service_role'}, {'session_id':None}):
            auth = SupabasePasswordAuth('https://school.supabase.co', 'key')
            auth._request = Mock(side_effect=[{'access_token':self.token(**claims), 'refresh_token':'refresh', 'expires_in':3600},
                                              {'id':str(USER)}])
            with self.subTest(claims=claims), self.assertRaises(LoginDenied): auth.authenticate('user', 'password')

    def test_get_user_failure_cannot_return_session(self):
        auth = SupabasePasswordAuth('https://school.supabase.co', 'key')
        auth._request = Mock(side_effect=[{'access_token':self.token(), 'refresh_token':'refresh', 'expires_in':3600},
                                          RuntimeError('private provider response')])
        with self.assertRaisesRegex(LoginDenied, '^Unable to sign in$'): auth.authenticate('user', 'password')


if __name__ == '__main__': unittest.main()
