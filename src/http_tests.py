
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


class NtkClient(object):


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


    def _token_for(self, user_id=None, token_type=None):
        if user_id:
            endpoint = '/rpc/token?id=' + user_id + '&token_type=' + token_type
        elif admin:
            endpoint = '/rpc/token?token_type=' + token_type
        return self._http_get(endpoint)


    def admin_table_create(self, table_def):
        pass


    def anon_register(self, user_id, user_metadata=None, owner=False, user=False):
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


    def owner_submit_data(self, table, data):
        pass


    def owner_get_own_data(self, table):
        pass


    def admin_group_create(self, group_name, group_metadata):
        pass


    def admin_group_add_members_individual(self, group_name, members):
        pass


    def admin_group_add_members_metadata(self, group_name, group_metadata):
        pass


    def admin_group_add_members_all_owners(self, group_name):
        pass


    def admin_table_group_access_grant(self, table, group_name):
        pass


    def user_get_data(self, table):
        pass


    def admin_table_group_access_revoke(self, table, group_name):
        pass


    def owner_check_group_memberships(self):
        pass


    def owner_group_remove(self, group_name):
        pass


    def admin_group_remove_members_all(self, group_name):
        pass


    def admin_group_delete(self, group_name):
        pass


    def check_access_logs(self, owner=False, admin=False):
        pass


    def owner_delete_own_data(self):
        pass


    def admin_user_delete(self, user_name):
        pass


    def admin_check_access_control_logs(self):
        pass


    def admin_check_user_group_removal_logs(self):
        pass


    def admin_check_user_initiated_data_deletion_logs(self):
        pass


class TestNtkHttpApi(unittest.TestCase):


    @classmethod
    def setUpClass(cls):
        cls.ntkc = NtkClient()


    @classmethod
    def tearDownClass(cls):
        # clean up all DB state
        pass


    def test_A_user_register(self):
        resp1 = self.ntkc.anon_register('1', user_metadata={'institution': 'A'}, owner=True)
        self.assertTrue(resp1.status_code, 200)
        resp2 = self.ntkc.anon_register('1', user_metadata={'institution': 'A'}, user=True)
        self.assertTrue(resp2.status_code, 200)


def main():
    if len(argv) < 2:
        print 'not enough arguments'
        print 'need either "--correctness" or "--scalability"'
        return
    runner = unittest.TextTestRunner()
    suite = []
    correctness_tests = ['test_A_user_register']
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
