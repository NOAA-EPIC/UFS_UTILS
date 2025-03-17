#!/bin/bash

# Copy files from the working directory to the
# output directory.

copy_data()
{

  set -x

  MEM=$1

  #SAVEDIR_MODEL_DATA=$SUBDIR/model_data/atmos/input
  SAVEDIR_MODEL_DATA=$SUBDIR/model/atmos/input
#  mkdir -p $SAVEDIR_MODEL_DATA
#  cp gfs_ctrl.nc $SAVEDIR_MODEL_DATA

  cp out.atm.tile1.nc ${SAVEDIR_MODEL_DATA}/gfs_data.tile7.nc
  cp out.sfc.tile1.nc ${SAVEDIR_MODEL_DATA}/sfc_data.tile7.nc

#  if [ ${MEM} == 'gdas' ]; then
#    SAVEDIR_ANALYSIS=$SUBDIR/analysis/atmos
#    mkdir -p $SAVEDIR_ANALYSIS
#    cp ${INPUT_DATA_DIR}/*abias* $SAVEDIR_ANALYSIS/
#    cp ${INPUT_DATA_DIR}/*radstat $SAVEDIR_ANALYSIS/
#  fi
}

set -x

MEMBER=$1
OUTDIR=$2
yy=$3
mm=$4
dd=$5
hh=$6
INPUT_DATA_DIR=$7

if [ ${MEMBER} == 'hires' ]; then
  MEMBER='gdas'
fi

set +x
echo 'COPY DATA TO OUTPUT DIRECTORY'
set -x

if [ ${MEMBER} == 'gdas' ] || [ ${MEMBER} == 'gfs' ]; then
  SUBDIR=$OUTDIR/${MEMBER}.${yy}${mm}${dd}/${hh}
#  rm -fr $SUBDIR
  copy_data ${MEMBER}
elif [ ${MEMBER} == 'enkf' ]; then  # v16 retro data only.
  MEMBER=1
  while [ $MEMBER -le 80 ]; do
    if [ $MEMBER -lt 10 ]; then
      MEMBER_CH="00${MEMBER}"
    else
      MEMBER_CH="0${MEMBER}"
    fi
    SUBDIR=$OUTDIR/enkfgdas.${yy}${mm}${dd}/${hh}/mem${MEMBER_CH}
    rm -fr $SUBDIR
    copy_data ${MEMBER}
    MEMBER=$(( $MEMBER + 1 ))
  done
else
  SUBDIR=$OUTDIR/enkfgdas.${yy}${mm}${dd}/${hh}/mem${MEMBER}
  copy_data ${MEMBER}
fi

exit 0
