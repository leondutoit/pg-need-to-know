
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
        # TODO: move these out
        # then the client user can configure the endpoints
        # however they want, pass in the spec, and call ahead
        # TODO: decide if want to pass dicts or json
        # dict will require deserialising and serialising data
        # _might_ be useful to deserialise if we want data
        # validation in this client
        self.url = 'http://localhost:3000'
        self.api_endpoints = {
            'user_register': '/rpc/user_register',
            'user_delete': '/rpc/user_delete'
        }


    def call_api(self, endpoint=None, data=None, identity=None, user_type=None):
        funcs = {
            self.api_endpoints['user_register']: self.user_register,
            self.api_endpoints['user_delete']: self.user_delete
        }
        if user_type == 'anon':
            token = None
        elif user_type == 'admin':
            token = self.token(token_type='admin')
        elif user_type == 'owner':
            token = self.token(user_id=identity, token_type='owner')
        elif user_type == 'user':
            token = self.token(user_id=identity, token_type='user')
        else:
            raise Exception('Unknown user type, cannot proceed')
        try:
            func = funcs[endpoint]
        except KeyError:
            raise Exception('Cannot look up client function based on provided endpoint')
        return func(endpoint, data, token)

    # helper functions

    def _assert_keys_present(self, required_keys, existing_keys):
        try:
            for rk in required_keys:
                assert rk in existing_keys
        except AssertionError:
            # make own exception
            raise Exception('Missing required key in data')


    def _http_get(self, endpoint, headers=None):
        url = self.url + endpoint
        if not headers:
            headers = None
        return requests.get(url, headers=headers)


    def _http_post_unauthenticated(self, endpoint, payload=None):
        return self._http_post(endpoint, {'Content-Type': 'application/json'},
                               payload)


    def _http_post_authenticated(self, endpoint, payload=None, token=None):
        headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token}
        return self._http_post(endpoint, headers, payload)


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

    def user_register(self, endpoint, data, token):
        self._assert_keys_present(['user_id', 'user_type', 'user_metadata'], data.keys())
        assert data['user_type'] in ['data_owner', 'data_user']
        return self._http_post_unauthenticated(endpoint, payload=data)


    def user_group_remove(self, group_name):
        pass


    def user_groups(self):
        pass


    def user_delete_data(self):
        pass


    def user_delete(self, endpoint, data, token):
        return self._http_post_authenticated(endpoint, payload=data, token=token)

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
        owner_data = {'user_id': '1', 'user_type': 'data_owner', 'user_metadata': {}}
        resp1 = self.ntkc.call_api(endpoint='/rpc/user_register',
                                   data=owner_data,
                                   user_type='anon')
        self.assertEqual(resp1.status_code, 200)
        user_data = {'user_id': '1', 'user_type': 'data_user', 'user_metadata': {}}
        resp2 = self.ntkc.call_api(endpoint='/rpc/user_register',
                                   data=user_data,
                                   user_type='anon')
        self.assertEqual(resp2.status_code, 200)


    def test_Z_user_delete(self):
        resp1 = self.ntkc.call_api(endpoint='/rpc/user_delete',
                                   data={'user_name': 'owner_1'},
                                   user_type='admin')
        self.assertEqual(resp1.status_code, 200)
        resp2 = self.ntkc.call_api(endpoint='/rpc/user_delete',
                                   data={'user_name': 'user_1'},
                                   user_type='admin')
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
