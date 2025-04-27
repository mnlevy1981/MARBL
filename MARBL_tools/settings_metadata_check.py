#!/usr/bin/env python

"""
Compare the units and longname for each MARBL setting to what is defined in the settings YAML file.

usage: settings_metadata_check.py [-h] [-o SETTINGS_OUTPUT] [-f DEFAULT_SETTINGS_FILE]

Compare metadata from MARBL settings to a JSON file

optional arguments:
  -h, --help            show this help message and exit
  -o SETTINGS_OUTPUT, --settings_output SETTINGS_OUTPUT
                        model output file to read metadata from (default: /Users/mlevy/NO_BACKUP/
                        codes/MARBL/tests/regression_tests/init/settings_metadata.yaml)
  -f DEFAULT_SETTINGS_FILE, --default_settings_file DEFAULT_SETTINGS_FILE
                        Location of JSON-formatted MARBL settings configuration file (default:
                        /Users/mlevy/NO_BACKUP/codes/MARBL/defaults/json/settings_latest.json)

"""

##################

def _parse_args():
    """ Parse command line arguments
    """

    import argparse

    desc = "Compare metadata from MARBL settings to a JSON file"
    parser = argparse.ArgumentParser(description=desc,
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    # File to compare to settings file
    # (default is $MARBLROOT/tests/regression_tests/init/settings_metadata.yaml)
    default = os.path.join(marbl_root,
                           "tests",
                           "regression_tests",
                           "init",
                           "settings_metadata.yaml"
                          )
    parser.add_argument("-o", "--settings_output", action="store", dest="settings_output",
                        default=default, help="model output file to read metadata from")

    # Command line argument to point to JSON settings file
    # (default is $MARBLROOT/defaults/json/settings_latest.json)
    default=os.path.join(marbl_root, "defaults", "json", "settings_latest.json")
    parser.add_argument("-f", "--default_settings_file", action="store",
                        dest="default_settings_file", default=default,
                        help="Location of JSON-formatted MARBL settings configuration file")

    return parser.parse_args()

##################

if __name__ == "__main__":
    import logging
    import os
    import sys
    import yaml

    # We need marbl_root in python path so we can import MARBL_tools from generate_settings_file()
    marbl_root = os.path.abspath(os.path.join(os.path.dirname(sys.argv[0]), ".."))
    sys.path.append(marbl_root)
    from MARBL_tools import MARBL_settings_class, LogFormatter, abort

    # Set up logging
    logger = logging.getLogger("__name__")
    handler = logging.StreamHandler()
    handler.setFormatter(LogFormatter())
    logger.setLevel(logging.DEBUG)
    logger.addHandler(handler)

    # Parse command line arguments
    args = _parse_args()

    with open(args.settings_output, encoding='utf-8') as file_in:
        yaml_in = yaml.safe_load(file_in)

    DefaultSettings = MARBL_settings_class(args.default_settings_file,
                                           "settings_file",
                                           grid=None,
                                           input_file=None,
                                           unit_system='cgs'
                                          )

    error_found = False
    for subcat_name in DefaultSettings.get_subcategory_names():
        for varname in DefaultSettings.get_settings_dict_variable_names(subcat_name):
            if varname in yaml_in:
                fortran_dict = yaml_in.pop(varname)
                json_dict = {}
                for keys in ['units', 'longname']:
                    json_dict[keys] = DefaultSettings.settings_dict[varname]['attrs'][keys]
                if varname == "particulate_flux_ref_depth":
                    # particulate_flux_ref_depth is a special case -- it is defined in JSON in m
                    # because, regardless of cgs vs mks, we want variables like FOO_100m
                    # DefaultSettings converts it to cm for cgs, but the Fortran keeps it in 'm'
                    json_dict['units'] = 'm'
                if fortran_dict['units'] != json_dict['units']:
                    logger.info(f'Variable {varname} has units "{fortran_dict["units"]}"' +
                                f' in Fortran and "{json_dict["units"]}" in JSON')
                if fortran_dict['longname'] != json_dict['longname']:
                    logger.info(f'Variable {varname} has longname "{fortran_dict["longname"]}"' +
                                f' in Fortran and "{json_dict["longname"]}" in JSON')
                    error_found = True
            else:
                logger.info('Variable %s not found in MARBL output', varname)
                error_found = True
    if len(yaml_in) > 0:
        logger.info('The following variables were defined in Fortran but not JSON:')
        for varname in yaml_in:
            logger.info('* %s', varname)
        error_found = True

    if error_found:
        logger.error('Differences found between JSON and Fortran metadata!')
        abort(1)
    else:
        logger.info('No differences found between JSON and Fortran metadata')
