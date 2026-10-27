"""Private periodic certificate-deadline worker; deployment stays opt-in.

The database supplies time, authority, due dates and rejection facts. This
process supplies neither an acting principal nor a decision/clock override.
Credentials are provided only by server deployment secret management.
"""
from __future__ import annotations
import argparse
import json
import math
import os
import threading
from uuid import UUID


def failure_code(error):
    code = getattr(error, 'sqlstate', None)
    return code if isinstance(code, str) and len(code) == 5 and code.isalnum() else 'WORKER_FAILURE'


class CertificateDeadlineWorker:
    def __init__(self, *, connect, batch_size=50, after_id=None):
        if type(batch_size) is not int or not 1 <= batch_size <= 100:
            raise ValueError('Deadline batch size must be 1..100')
        self.connect, self.batch_size = connect, batch_size
        self.cursor = None if after_id is None else str(UUID(str(after_id)))

    def _rpc(self, sql, params):
        with self.connect() as conn:
            with conn.transaction():
                return conn.execute(sql, params).fetchone()[0]

    def run_once(self):
        """One bounded page; each item commits or rolls back independently.

        The in-memory keyset cursor advances past failures and wraps at end.
        One-shot supervisors may persist next_cursor and pass --after-id. A
        restart may retry work safely; the DB terminal/source uniqueness guards
        prevent duplicate rejection, receipt and notification events.
        """
        page = self._rpc('SELECT app_private.db03_deadline_candidates(%s,%s)', (self.cursor, self.batch_size))
        if not page and self.cursor is not None:
            self.cursor = None
            page = self._rpc('SELECT app_private.db03_deadline_candidates(%s,%s)', (None, self.batch_size))
        report = dict(scanned=len(page), rejected=0, unchanged=0, failed=0, failures=[])
        for application in page:
            application = str(UUID(str(application)))
            try:
                result = self._rpc('SELECT app_private.db03_expire_admission_certificate(%s)', (application,))
                if result['status'] not in ('REJECTED', 'UNCHANGED'):
                    raise RuntimeError('Unexpected protected deadline result')
                report['rejected' if result['status'] == 'REJECTED' else 'unchanged'] += 1
            except Exception as error:
                # Never log exception text: database/transport errors may carry
                # credentials, bound private data or provider paths.
                report['failed'] += 1
                report['failures'].append(dict(application_id=application, code=failure_code(error)))
            self.cursor = application
        report['next_cursor'] = self.cursor
        return report

    def run_forever(self, *, interval_seconds, stop_event=None, report=print):
        if isinstance(interval_seconds, bool) or not isinstance(interval_seconds, (int, float)) or not math.isfinite(interval_seconds) or interval_seconds <= 0:
            raise ValueError('Explicit finite positive deadline interval required')
        stop = threading.Event() if stop_event is None else stop_event
        while not stop.is_set():
            report(json.dumps(self.run_once(), sort_keys=True))
            if stop.wait(interval_seconds):
                break


def main(argv=None):
    parser = argparse.ArgumentParser(description='Private server certificate deadline worker')
    parser.add_argument('--once', action='store_true')
    parser.add_argument('--batch-size', type=int, default=50)
    parser.add_argument('--after-id')
    parser.add_argument('--interval-seconds', type=float)
    args = parser.parse_args(argv)
    if not args.once and args.interval_seconds is None:
        parser.error('Provide --once or an explicit --interval-seconds')
    dsn = os.environ.get('DB03_DEADLINE_DATABASE_DSN')
    if not dsn:
        parser.error('Server DB03_DEADLINE_DATABASE_DSN is required')
    try:
        import psycopg
        worker = CertificateDeadlineWorker(connect=lambda: psycopg.connect(dsn, autocommit=True), batch_size=args.batch_size, after_id=args.after_id)
        if args.once:
            result = worker.run_once()
            print(json.dumps(result, sort_keys=True))
            return 1 if result['failed'] else 0
        worker.run_forever(interval_seconds=args.interval_seconds)
        return 0
    except KeyboardInterrupt:
        return 0
    except Exception as error:
        print(json.dumps(dict(status='FAILED', code=failure_code(error)), sort_keys=True))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
