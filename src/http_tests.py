
"""Testing pg-need-to-know via postgrest."""

from sys import argv
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


    def admin_table_create(self, table_def):
        pass


    def anon_register(self, user_id, owner=False, user=False):
        pass


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


    def admin_table_group_access_grant(table, group_name):
        pass


    def user_get_data(table):
        pass


    def admin_table_group_access_revoke(table, group_name):
        pass


    def owner_check_group_memberships():
        pass


    def owner_group_remove(group_name):
        pass


    def admin_group_remove_members_all(group_name):
        pass


    def admin_group_delete(group_name):
        pass


    def check_access_logs(owner=False, admin=False):
        pass


    def owner_delete_own_data():
        pass


    def admin_user_delete(user_name):
        pass


    def admin_check_access_control_logs():
        pass


    def admin_check_user_group_removal_logs():
        pass


    def admin_check_user_initiated_data_deletion_logs():
        pass


class TestNtkHttpApi(unittest.TestCase):


    @classmethod
    def setUpClass(cls):
        cls.ntkc = NtkClient()


    @classmethod
    def tearDownClass(cls):
        pass


    def test1(self):
        assert True


def main():
    if len(argv) < 2:
        print 'not enough arguments'
        print 'need either "--correctness" or "--scalability"'
        return
    runner = unittest.TextTestRunner()
    suite = []
    correctness_tests = ['test1']
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
