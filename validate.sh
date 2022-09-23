#!/usr/bin/env bash
set -ex

# python
isort --check .
black --check .
flake8 .
pylint (git ls-files --exclude-standard '*.py')
trivy fs --security-checks vuln .

# shell
find . -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.ksh' -o -name '*.bashrc' -o -name '*.bash_profile' -o -name '*.bash_login' -o -name '*.bash_logout' \) | xargs shellcheck --format gcc

# cloudformation
cfn_nag_scan .

#pydocstyle awswrangler/ --convention=numpy
#doc8 --ignore D005,D002 --max-line-length 120 docs/source

#covestro validate.sh{isort, black, flake8, pylint, shellcheck, cfn-nag, trivy}
