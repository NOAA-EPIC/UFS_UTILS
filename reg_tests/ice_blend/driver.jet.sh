#!/bin/bash

#-----------------------------------------------------------------------------
#
# Run ice_blend consistency test on Jet.
#
# Set $DATA to your working directory.  Set the project code (SBATCH -A)
# and queue (SBATCH -q) as appropriate.
#
# Invoke the script as follows:  sbatch $script
#
# Log output is placed in consistency.log.  A summary is
# placed in summary.log
#
# The test fails when its output does not match the baseline file
# as determined by the 'cmp' command.  The baseline file is
# stored in HOMEreg.
#
#-----------------------------------------------------------------------------

#SBATCH --nodes=1
#SBATCH --partition=sjet
#SBATCH --time 0:01
#SBATCH --account=emcda
#SBATCH --job-name=ice_blnd
#SBATCH -o consistency.log
#SBATCH -e consistency.log

set -x

source ../../sorc/machine-setup.sh > /dev/null 2>&1
module use ../../modulefiles
module load build.$target.intelllvm
module load wgrib2/2.0.8
module load grib-util/1.3.0
set +x
module list
set -x

export DATA="${WORK_DIR:-/lfs5/HFIP/emcda/$LOGNAME/stmp}"
export DATA="${DATA}/reg-tests/ice-blend"

#-----------------------------------------------------------------------------
# Should not have to change anything below.
#-----------------------------------------------------------------------------

export UPDATE_BASELINE="FALSE"
#export UPDATE_BASELINE="TRUE"

if [ "$UPDATE_BASELINE" = "TRUE" ]; then
  source ../get_hash.sh
fi

export WGRIB=/apps/wgrib/1.8.1.0b/bin/wgrib

export HOMEreg=/lfs5/HFIP/hfv3gfs/emc.nemspara/role.ufsutils/ufs_utils/reg_tests/ice_blend

export HOMEgfs=$PWD/../..

rm -fr $DATA

./ice_blend.sh

exit 0
