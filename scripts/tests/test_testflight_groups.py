import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('testflight_groups', SCRIPTS / 'testflight-groups.py')
groups = importlib.util.module_from_spec(spec)
spec.loader.exec_module(groups)

APP = {'bundleIdentifier': 'com.example.demo', 'displayName': 'Demo', 'teamIdentifier': 'ABCDE12345',
       'marketingVersion': '1.0', 'buildNumber': '1', 'minimumIOS': '17.0'}
APP_RECORD = {'id': '6820716653', 'attributes': {'bundleId': 'com.example.demo'}}
USERS = [{'id': 'u1', 'attributes': {'username': 'owner@example.com', 'roles': ['ACCOUNT_HOLDER']}}]
GOOD_GROUP = {'id': 'g1', 'attributes': {'name': 'dev-auto', 'isInternalGroup': True, 'hasAccessToAllBuilds': True}}
BAD_GROUP = {'id': 'g0', 'attributes': {'name': 'dev-auto', 'isInternalGroup': True, 'hasAccessToAllBuilds': False}}


class FakeReader:
    def __init__(self, groups_list=(), testers=(), users=USERS, apps=(APP_RECORD,)):
        self.groups_list, self.testers, self.users, self.apps = list(groups_list), list(testers), list(users), list(apps)
        self.commands = []

    def read(self, command):
        self.commands.append(command)
        head = tuple(command[:3])
        if head[:2] == ('apps', 'list'):
            return 'verified', self.apps
        if head == ('testflight', 'groups', 'list'):
            return 'verified', self.groups_list
        if head == ('testflight', 'testers', 'list'):
            return 'verified', self.testers
        if head[:2] == ('users', 'list'):
            return 'verified', self.users
        return 'not_verified', None


class FakeWriter:
    def __init__(self, reader, create_status='completed', add_status='completed'):
        self.reader, self.create_status, self.add_status, self.commands = reader, create_status, add_status, []

    def write(self, command):
        self.commands.append(command)
        if command[:3] == ['testflight', 'groups', 'create'] and self.create_status == 'completed':
            self.reader.groups_list.append(GOOD_GROUP)
            return 'completed', {'id': 'g1', 'type': 'betaGroups'}
        if command[:3] == ['testflight', 'testers', 'add'] and self.add_status == 'completed':
            self.reader.testers.append({'id': 't1', 'attributes': {'email': command[command.index('--email') + 1]}})
            return 'completed', {'id': 't1'}
        return self.create_status if 'create' in command else self.add_status, None


DISPATCH = {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/main', 'GITHUB_EVENT_NAME': 'workflow_dispatch'}


class PlanTests(unittest.TestCase):
    def test_plan_creates_group_and_adds_owner_when_absent(self):
        reader = FakeReader()
        report = groups.plan(APP, reader, 'dev-auto', 'ACCOUNT_HOLDER')
        self.assertEqual([a['action'] for a in report['actions']], ['create_group', 'add_tester'])
        self.assertEqual((report['candidateTesters'], report['alreadyMembers'], report['existingGroup']), (1, 0, None))
        self.assertEqual(report['_emails'], ['owner@example.com'])
        self.assertIn(['testflight', 'groups', 'list', '--app', '6820716653', '--name', 'dev-auto'], reader.commands)

    def test_plan_is_noop_when_group_correct_and_owner_member(self):
        reader = FakeReader(groups_list=[GOOD_GROUP], testers=[{'id': 't1', 'attributes': {'email': 'owner@example.com'}}])
        report = groups.plan(APP, reader, 'dev-auto', 'ACCOUNT_HOLDER')
        self.assertEqual(report['actions'], [])
        self.assertEqual(report['existingGroup'], {'id': 'g1', 'internal': True, 'accessAllBuilds': True})
        self.assertEqual(report['alreadyMembers'], 1)

    def test_plan_flags_group_without_all_builds_access_for_manual_review(self):
        report = groups.plan(APP, FakeReader(groups_list=[BAD_GROUP]), 'dev-auto', 'ACCOUNT_HOLDER')
        self.assertEqual(report['actions'][0]['action'], 'manual_review')
        with self.assertRaises(groups.GroupsError):
            groups.apply(report, FakeWriter(FakeReader()), FakeReader(), DISPATCH)

    def test_plan_validates_inputs_and_requires_one_app(self):
        with self.assertRaises(groups.GroupsError):
            groups.plan(APP, FakeReader(), 'bad/name', 'ACCOUNT_HOLDER')
        with self.assertRaises(groups.GroupsError):
            groups.plan(APP, FakeReader(), 'dev-auto', 'DEVELOPER')
        with self.assertRaises(groups.release.ReleaseError):
            groups.plan(APP, FakeReader(apps=[]), 'dev-auto', 'ACCOUNT_HOLDER')

    def test_summary_and_report_never_contain_emails(self):
        report = groups.plan(APP, FakeReader(), 'dev-auto', 'ACCOUNT_HOLDER')
        public = {k: v for k, v in report.items() if k != '_emails'}
        self.assertNotIn('owner@example.com', json.dumps(public))
        self.assertNotIn('owner@example.com', groups.summary(public))


class ApplyTests(unittest.TestCase):
    def test_apply_refused_outside_main_dispatch(self):
        report = groups.plan(APP, FakeReader(), 'dev-auto', 'ACCOUNT_HOLDER')
        for env in ({}, {**DISPATCH, 'GITHUB_REF': 'refs/heads/feature'}, {**DISPATCH, 'GITHUB_EVENT_NAME': 'push'}):
            with self.assertRaises(groups.GroupsError):
                groups.apply(report, FakeWriter(FakeReader()), FakeReader(), env)

    def test_apply_creates_group_adds_tester_and_verifies(self):
        reader = FakeReader()
        report = groups.plan(APP, reader, 'dev-auto', 'ACCOUNT_HOLDER')
        writer = FakeWriter(reader)
        result = groups.apply(report, writer, reader, DISPATCH)
        self.assertEqual(result['status'], 'applied')
        self.assertEqual(writer.commands[0], ['testflight', 'groups', 'create', '--app', '6820716653', '--name', 'dev-auto',
                                              '--internal', '--access-all-builds'])
        self.assertEqual(writer.commands[1][:3], ['testflight', 'testers', 'add'])
        self.assertEqual(writer.commands[1][writer.commands[1].index('--group') + 1], 'g1')
        self.assertEqual(result['verifiedGroup'], {'internal': True, 'accessAllBuilds': True, 'testerCount': 1})
        self.assertNotIn('_emails', result)
        self.assertNotIn('owner@example.com', json.dumps(result))

    def test_apply_reports_incomplete_when_create_denied(self):
        reader = FakeReader()
        report = groups.plan(APP, reader, 'dev-auto', 'ACCOUNT_HOLDER')
        result = groups.apply(report, FakeWriter(reader, create_status='inaccessible'), reader, DISPATCH)
        self.assertEqual(result['status'], 'incomplete')
        self.assertEqual(result['results'], [{'action': 'create_group', 'status': 'inaccessible'}])
        self.assertIsNone(result['verifiedGroup'])

    def test_writer_classifies_errors_without_echoing_output(self):
        writer = groups.Writer.__new__(groups.Writer)
        writer.binary, writer.env = '/bin/false', {}
        with mock.patch.object(groups.subprocess, 'run') as run:
            run.return_value = mock.Mock(returncode=1, stderr='403 Forbidden: secret details here', stdout='')
            self.assertEqual(writer.write(['testflight', 'groups', 'create']), ('inaccessible', None))
            run.return_value = mock.Mock(returncode=0, stderr='', stdout='{"data": {"id": "g9", "type": "betaGroups"}}')
            self.assertEqual(writer.write(['testflight', 'groups', 'create']), ('completed', {'id': 'g9', 'type': 'betaGroups'}))
            run.return_value = mock.Mock(returncode=0, stderr='', stdout='not json')
            self.assertEqual(writer.write(['x']), ('not_verified', None))
            self.assertTrue(all(call.args[0][-2:] == ['--output', 'json'] for call in run.call_args_list))


if __name__ == '__main__':
    unittest.main()
