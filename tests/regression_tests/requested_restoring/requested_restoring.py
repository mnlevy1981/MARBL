#!/usr/bin/env python

from sys import path
import os

path.insert(0, os.path.join('..', '..', 'python_for_tests'))
from marbl_testing_class import MARBL_testcase

mt = MARBL_testcase()

mt.parse_args(desc='Run full MARBL setup (config, init, and complete) and print '
                   'list of all the tracers MARBL will restore',
              DefaultSettingsFile='../../input_files/settings/marbl_with_restore.settings')

mt.build_exe()

mt.run_exe()
