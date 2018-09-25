
"""Testing pg-need-to-know via postgrest."""

from sys import argv
import json
import unittest

import requests


TABLES = {
    't1': {},
    't2': {},
    't3': {},
    't4': {},
}


class PgNeedToKnowClient(object):


    def __init__(self):
        self.url = 'http://localhost:3000'


    def _http_get(self, endpoint, headers=None):
        url = self.url + endpoint
        if not headers:
            headers = None
        return requests.get(url, headers=headers)


    def _http_post(self, endpoint, headers, payload=None):
        url = self.url + endpoint
        if payload:
            return requests.post(url, headers=headers, data=json.dumps(payload))
        else:
            return requests.post(url, headers=headers)


    def token(self, user_id=None, token_type=None):
        if user_id:
            endpoint = '/rpc/token?id=' + user_id + '&token_type=' + token_type
        else:
            endpoint = '/rpc/token?token_type=' + token_type
        resp = self._http_get(endpoint)
        return json.loads(resp.text)['token']


    # table functions

    def table_create(self, definition, type):
        pass


    def table_describe(self, table_name, table_description):
        pass


    def table_describe_columns(self, table_name, column_descriptions):
        pass


    def table_metadata(self, table_name):
        pass


    def table_group_access_grant(self, table_name, group_name):
        pass


    def table_group_access_revoke(self, table_name, group_name):
        pass

    # user functions

    def user_register(self, user_id, user_metadata=None, owner=False, user=False):
        endpoint = '/rpc/user_register'
        headers = {'Content-Type': 'application/json'}
        if owner:
            data = {'user_id': user_id, 'user_type': 'data_owner'}
        elif user:
            data = {'user_id': user_id, 'user_type': 'data_user'}
        if user_metadata:
            data['user_metadata'] = user_metadata
        else:
            data['user_metadata'] = {}
        return self._http_post(endpoint, headers, payload=data)


    def user_group_remove(self, group_name):
        pass


    def user_groups(self):
        pass


    def user_delete_data(self):
        pass


    def user_delete(self, user_name):
        token = self.token(token_type='admin')
        return self._http_post('/rpc/user_delete',
                               headers={'Content-Type': 'application/json',
                                        'Authorization': 'Bearer ' + token},
                               payload={'user_name': user_name})

    # group functions

    def group_create(self, group_name, group_metadata):
        pass


    def group_add_members(self):
        pass


    def _group_add_members_members(self, group_name, members):
        pass


    def _group_add_members_metadata(self, group_name, group_metadata):
        pass


    def _group_add_members_all_owners(self, group_name):
        pass


    def _group_add_members_all_users(self, group_name):
        pass


    def _group_add_members_all(self, group_name):
        pass


    def group_list_members(self, group_name):
        pass


    def group_remove_members(self, group_name):
        pass


    def group_delete(self, group_name):
        pass

    # informational views, tables, and event logs

    def get_table_overview(self):
        pass


    def get_user_registrations(self):
        pass


    def get_groups(self):
        pass


    def get_event_log_user_group_removals(self):
        pass


    def get_event_log_user_data_deletions(self):
        pass


    def get_event_log_data_access(self):
        pass


    def get_event_log_access_control(self):
        pass

    # utility functions (not in the SQL API)

    def post_data(self, table, data):
        pass


    def get_data(self, table):
        pass


class TestNtkHttpApi(unittest.TestCase):


    @classmethod
    def setUpClass(cls):
        cls.ntkc = PgNeedToKnowClient()


    @classmethod
    def tearDownClass(cls):
        # clean up all DB state
        pass


    def register_many(n, owner=False, user=False):
        pass


    def test_A_user_register(self):
        resp1 = self.ntkc.user_register('1', user_metadata={'institution': 'A'}, owner=True)
        self.assertEqual(resp1.status_code, 200)
        resp2 = self.ntkc.user_register('1', user_metadata={'institution': 'A'}, user=True)
        self.assertEqual(resp2.status_code, 200)


    def test_Z_user_delete(self):
        resp1 = self.ntkc.user_delete('owner_1')
        self.assertEqual(resp1.status_code, 200)
        resp2 = self.ntkc.user_delete('user_1')
        self.assertEqual(resp2.status_code, 200)


def main():
    if len(argv) < 2:
        print 'not enough arguments'
        print 'need either "--correctness" or "--scalability"'
        return
    runner = unittest.TextTestRunner()
    suite = []
    correctness_tests = ['test_A_user_register', 'test_Z_user_delete']
    scalability_tests = []
    correctness_tests.sort()
    if argv[1] == '--correctness':
        suite.append(unittest.TestSuite(map(TestNtkHttpApi, correctness_tests)))
    elif argv[1] == '--scalability':
        suite.append(unittest.TestSuite(map(TestNtkHttpApi, scalability_tests)))
    else:
        print "unrecognised argument"
        print 'need either "--correctness" or "--scalability"'
        return
    map(runner.run, suite)
    return


if __name__ == '__main__':
    main()
