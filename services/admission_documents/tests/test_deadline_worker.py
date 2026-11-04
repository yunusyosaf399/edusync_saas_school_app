import json
import threading
import unittest
from services.admission_documents.deadline_worker import CertificateDeadlineWorker, failure_code

A='11111111-1111-4111-8111-111111111111'
B='22222222-2222-4222-8222-222222222222'


class DeadlineWorkerBoundary(unittest.TestCase):
    def worker(self, responses, **kwargs):
        worker=CertificateDeadlineWorker(connect=lambda:None, **kwargs);calls=[];answers=iter(responses)
        def rpc(sql,params):
            calls.append((sql,params));answer=next(answers)
            if isinstance(answer,Exception):raise answer
            return answer
        worker._rpc=rpc
        return worker,calls
    def test_one_bounded_page_uses_only_application_ids(self):
        worker,calls=self.worker([[A,B],{'status':'REJECTED'},{'status':'UNCHANGED'}],batch_size=2)
        report=worker.run_once()
        self.assertEqual((report['rejected'],report['unchanged'],report['next_cursor']),(1,1,B))
        self.assertEqual(calls[0][1],(None,2));self.assertEqual(calls[1][1],(A,))
    def test_one_item_failure_does_not_block_other_items_or_expose_error(self):
        worker,calls=self.worker([[A,B],RuntimeError('password=private bytes'),{'status':'REJECTED'}])
        report=worker.run_once()
        self.assertEqual((report['failed'],report['rejected'],report['next_cursor']),(1,1,B))
        self.assertNotIn('password',json.dumps(report));self.assertEqual(report['failures'][0]['code'],'WORKER_FAILURE')
    def test_cursor_advances_and_wraps_past_failed_items(self):
        worker,calls=self.worker([[A],RuntimeError('failure'),[],[B],{'status':'REJECTED'}])
        worker.run_once();report=worker.run_once()
        self.assertEqual(calls[2][1],(A,50));self.assertEqual(calls[3][1],(None,50));self.assertEqual(report['next_cursor'],B)
    def test_discovery_authorization_failure_propagates(self):
        worker,calls=self.worker([RuntimeError('authority denied')])
        with self.assertRaises(RuntimeError):worker.run_once()
        self.assertEqual(len(calls),1)
    def test_bounded_batch_and_explicit_finite_interval(self):
        for batch in (0,101,True,1.5):
            with self.assertRaises(ValueError):CertificateDeadlineWorker(connect=lambda:None,batch_size=batch)
        worker,calls=self.worker([])
        for interval in (0,-1,float('inf'),float('nan'),True):
            with self.assertRaises(ValueError):worker.run_forever(interval_seconds=interval)
    def test_periodic_loop_respects_stop_and_reports_counts(self):
        worker,calls=self.worker([[]]);stop=threading.Event();reports=[]
        def report(value):reports.append(json.loads(value));stop.set()
        worker.run_forever(interval_seconds=1,stop_event=stop,report=report)
        self.assertEqual(reports[0]['scanned'],0);self.assertEqual(len(calls),1)
