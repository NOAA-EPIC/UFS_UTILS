#!/bin/bash

#SBATCH -J fv3_grid_driver
#SBATCH -A nems
#SBATCH --open-mode=truncate
#SBATCH -o log.fv3_grid_driver
#SBATCH -e log.fv3_grid_driver
#SBATCH --nodes=6 --ntasks-per-node=12
#SBATCH --partition=hera
#SBATCH -q batch
#SBATCH -t 00:30:00

#-----------------------------------------------------------------------
# Driver script to create a cubic-sphere based model grid on Hera.
#
# Produces the following files (netcdf, each tile in separate file):
#   1) 'mosaic' and 'grid' files containing lat/lon and other
#      records that describe the model grid.
#   2) 'oro' files containing land mask, terrain and gravity
#      wave drag fields.
#   3) Surface climo fields, such as soil type, vegetation
#      greenness and albedo.
#
# Note: The sfc_climo_gen program only runs with an
#       mpi task count that is a multiple of six.  This is
#       an ESMF library requirement.  Large grids may require
#       tasks spread across multiple nodes or to be run on
#       'bigmem' nodes (#SBATCH --partition=bigmem). The 
#       orography code benefits from threads.
#
# To run, do the following:
#
#   1) Set "C" resolution, "res" - Example: res=96.
#   2) Set grid type ("gtype").  Valid choices are
#         "uniform"  - global uniform grid
#         "stretch"  - global stretched grid
#         "nest"     - global stretched grid with nest
#         "regional_gfdl" - stand-alone gfdl regional grid
#         "regional_esg"  - stand-alone extended Schmidt gnomonic
#                           (esg) regional grid
#   3) For "uniform" and "regional_gfdl" grids - to include lake
#      fraction and depth, set "add_lake" to true, and the
#      "lake_cutoff" value.
#   4) For "stretch" and "nest" grids, set the stretching factor -
#       "stretch_fac", and center lat/lon of highest resolution
#      tile - "target_lat" and "target_lon".
#   5) For "nest" grids, set the refinement ratio - "refine_ratio",
#      the starting/ending i/j index location within the parent
#      tile - "istart_nest", "jstart_nest", "iend_nest", "jend_nest"
#   6) For "regional_gfdl" grids, set the "halo".  Default is three
#      rows/columns.
#   7) For "regional_esg" grids, set center lat/lon of grid,
#      - "target_lat/lon" - the i/j dimensions - "i/jdim", the
#      x/y grid spacing - "delx/y", and halo.
#   8) Set working directory - TEMP_DIR - and path to the repository
#      clone - home_dir.
#   9) To use the GSL orographic drag suite, set 'make_gsl_orog' to true.
#  10) Set 'soil_veg_src' and 'veg_type_src' to choose the 
#      soil type and vegetation type data.
#  11) Submit script: "sbatch $script".
#  12) All files will be placed in "out_dir".
#
#-----------------------------------------------------------------------

set -x

compiler=${compiler:-"intelllvm"}
source ../sorc/machine-setup.sh > /dev/null 2>&1
module use ../modulefiles
module load build.$target.$compiler
module list

#-----------------------------------------------------------------------
# Set grid specs here.
#-----------------------------------------------------------------------

export gtype=nest              # 'uniform', 'stretch', 'nest', 
                               # 'regional_gfdl', 'regional_esg'.

export nest_res=192              # global nest res
export make_gsl_orog=true     # When 'true' will output 'oro' files for
                               # the GSL orographic drag suite.

export vegsoilt_frac='.false.' # When .false., output dominant soil and 
                               # vegetation type category. When .true.,
                               # output fraction of each category and
                               # the dominant category. A Fortran logical,
                               # so include the dots.

export veg_type_src="viirs.v3.igbp.30s" #  Vegetation type data.
                                # For viirs-based vegetation type data, set to:
                                # 1) "viirs.v3.igbp.30s" for global 30s data
                                # For the modis-based data, set to:
                                # 1) "modis.igbp.0.05" for global 0.05-deg data
                                # 2) "modis.igbp.0.03" for global 0.03-deg data
                                # 3) "modis.igbp.conus.30s" for CONUS 30s data
                                # 4) "modis.igbp.nh.30s" for N Hemis 30s data
                                # 5) "modis.igbp.30s" for global 30s data

export soil_type_src="bnu.v3.30s" #  Soil type data. 
                                # For STATSGO data
                                # 1) "statsgo.0.05" for global 0.05-deg data
                                # 2) "statsgo.0.03" for global 0.03-deg data
                                # 3) "statsgo.conus.30s" for CONUS 30s data
                                # 4) "statsgo.nh.30s" for NH 30s data
                                # 5) "statsgo.30s" for global 30s data
                                 # For Beijing Norm. Univ. data
                                # 1) "bnu.v3.30s" for global 30s data.

# choose dataset sources for lakefrac & lakedepth so that lake_data_srce=LakeFrac_LakeDepth; 
# available options are 'MODISP_GLDBV3', 'MODISP_GLOBATHY', 'VIIRS_GLDBV3', 'VIIRS_GLOBATHY' & 'GLDBV3'
export lake_data_srce=MODISP_GLDBV3 

if [ $gtype = uniform ]; then
  export res=96
  export add_lake=true         # Add lake frac and depth to orography data.
  export lake_cutoff=0.50      # return 0 if lake_frac <  lake_cutoff & add_lake=T
  export binary_lake=1         # return 1 if lake_frac >= lake_cutoff & add_lake=T
  export ocn=${ocn:-"100"}     # use one of  "025", "050", "100", "500". Cannot be empty
elif [ $gtype = stretch ]; then
  export add_lake=true        # Add lake frac and depth to orography data.
  export lake_cutoff=0.20      # lake frac < lake_cutoff ignored when add_lake=T
  if [ $nest_res = 768 ]; then # UFS_AR nest global C768
    export res=768
    export stretch_fac=1.0001    # Stretching factor for the grid
    export target_lon=-135.0     # Center longitude of the highest resolution tile
    export target_lat=32.5       # Center latitude of the highest resolution tile
  elif [ $nest_res = 384 ]; then # UFS_AR nest global C384
    export res=384
    export stretch_fac=1.0001    # Stretching factor for the grid
    export target_lon=-135.0     # Center longitude of the highest resolution tile
    export target_lat=32.5       # Center latitude of the highest resolution tile
  elif [ $nest_res = 192 ]; then # UFS_AR nest global 192
    export res=192
    export stretch_fac=1.0001    # Stretching factor for the grid
    export target_lon=-135.0     # Center longitude of the highest resolution tile
    export target_lat=32.5       # Center latitude of the highest resolution tile
  elif [ $nest_res = 96 ]; then  # UFS_AR nest global C96
    export res=96
    export stretch_fac=1.0001       # Stretching factor for the grid
    export target_lon=-135.0      # Center longitude of the highest resolution tile
    export target_lat=32.5       # Center latitude of the highest resolution tile
  fi
  # Original stuff from Ning.
  # export res=96
  # export stretch_fac=1.5       # Stretching factor for the grid
  # export target_lon=-97.5      # Center longitude of the highest resolution tile
  # export target_lat=35.5       # Center latitude of the highest resolution tile
elif [ $gtype = nest ] || [ $gtype = regional_gfdl ]; then
  export add_lake=true        # Add lake frac and depth to orography data.
  export lake_cutoff=0.20      # lake frac < lake_cutoff ignored when add_lake=T
  if [ $nest_res = 768 ]; then # UFS_AR nest global C768
    export res=768
    export stretch_fac=1.0001    # Stretching factor for the grid
    export target_lon=-135.0     # Center longitude of the highest resolution tile
    export target_lat=32.5       # Center latitude of the highest resolution tile
    export refine_ratio=4        # The refinement ratio
    export istart_nest=47        # Starting i-direction index of nest grid in parent tile supergrid
    export jstart_nest=143       # Starting j-direction index of nest grid in parent tile supergrid
    export iend_nest=1486        # Ending i-direction index of nest grid in parent tile supergrid
    export jend_nest=1294        # Ending j-direction index of nest grid in parent tile supergrid
  elif [ $nest_res = 384 ]; then # UFS_AR nest global C384
    export res=384
    export stretch_fac=1.0001    # Stretching factor for the grid
    export target_lon=-135.0     # Center longitude of the highest resolution tile
    export target_lat=32.5       # Center latitude of the highest resolution tile
    export refine_ratio=4        # The refinement ratio
    export istart_nest=25        # Starting i-direction index of nest grid in parent tile supergrid
    export jstart_nest=73        # Starting j-direction index of nest grid in parent tile supergrid
    export iend_nest=744         # Ending i-direction index of nest grid in parent tile supergrid
    export jend_nest=648         # Ending j-direction index of nest grid in parent tile supergrid
  elif [ $nest_res = 192 ]; then # UFS_AR nest global 192
    export res=192
    export stretch_fac=1.0001    # Stretching factor for the grid
    export target_lon=-135.0     # Center longitude of the highest resolution tile
    export target_lat=32.5       # Center latitude of the highest resolution tile
    export refine_ratio=4        # The refinement ratio
    export istart_nest=13        # Starting i-direction index of nest grid in parent tile supergrid
    export jstart_nest=37        # Starting j-direction index of nest grid in parent tile supergrid
    export iend_nest=372         # Ending i-direction index of nest grid in parent tile supergrid
    export jend_nest=322         # Ending j-direction index of nest grid in parent tile supergrid
  elif [ $nest_res = 96 ]; then  # UFS_AR nest global C96
    export res=96
    export stretch_fac=1.0001       # Stretching factor for the grid
    export target_lon=-135.0      # Center longitude of the highest resolution tile
    export target_lat=32.5       # Center latitude of the highest resolution tile
    export refine_ratio=4        # The refinement ratio
    export istart_nest=7       # Starting i-direction index of nest grid in parent tile supergrid
    export jstart_nest=17       # Starting j-direction index of nest grid in parent tile supergrid
    export iend_nest=186        # Ending i-direction index of nest grid in parent tile supergrid
    export jend_nest=160        # Ending j-direction index of nest grid in parent tile supergrid
  fi
#  export stretch_fac=1.5       # Stretching factor for the grid
#  export target_lon=-97.5      # Center longitude of the highest resolution tile
#  export target_lat=38.5       # Center latitude of the highest resolution tile
#  export refine_ratio=3        # The refinement ratio
#  export istart_nest=123       # Starting i-direction index of nest grid in parent tile supergrid
#  export jstart_nest=331       # Starting j-direction index of nest grid in parent tile supergrid
#  export iend_nest=1402        # Ending i-direction index of nest grid in parent tile supergrid
#  export jend_nest=1194        # Ending j-direction index of nest grid in parent tile supergrid
  export halo=3                # Lateral boundary halo
elif [ $gtype = regional_esg ] ; then
  export res=-999              # equivalent resolution is computed
  export target_lon=-97.5      # Center longitude of grid
  export target_lat=35.5       # Center latitude of grid
  export idim=301              # Dimension of grid in 'i' direction
  export jdim=200              # Dimension of grid in 'j' direction
  export delx=0.0585           # Grid spacing (in degrees) in the 'i' direction
                               # on the SUPERGRID (which has twice the resolution of
                               # the model grid).  The physical grid spacing in the 'i'
                               # direction is related to delx as follows:
                               #    distance = 2*delx*(circumf_Earth/360 deg)
  export dely=0.0585           # Grid spacing (in degrees) in the 'j' direction.
  export halo=4                # number of row/cols for halo
fi

#-----------------------------------------------------------------------
# Check paths.
#
#   home_dir - location of repository.
#   TEMP_DIR - working directory.
#   out_dir  - where files will be placed upon completion.
#-----------------------------------------------------------------------

export home_dir=$SLURM_SUBMIT_DIR/..
#export TEMP_DIR=/scratch2/NCEPDEV/stmp1/$LOGNAME/fv3_grid.$gtype
#export out_dir=/scratch2/NCEPDEV/stmp1/$LOGNAME/my_grids
samdir=/scratch2/BMC/wrfruc/Samuel.Trahan/westwater/sijie-inf/ning-grid-stuff/UFS_UTILS_ufscom/driver_scripts/
samdir=/scratch1/NCEPDEV/nems/David.Burrows/ufs-utils-tiled/ufs_utils_tile_dev_v3/driver_scripts
export TEMP_DIR=$samdir/fv3_grid/$gtype-$nest_res/temp
export out_dir=$samdir/fv3_grid/$gtype-$nest_res/out
#-----------------------------------------------------------------------
# Should not need to change anything below here.
#-----------------------------------------------------------------------

export APRUN=time
export APRUN_SFC=srun
export OMP_NUM_THREADS=24
export OMP_STACKSIZE=2048m

ulimit -a
ulimit -s unlimited

#-----------------------------------------------------------------------
# Start script.
#-----------------------------------------------------------------------

$home_dir/ush/fv3gfs_driver_grid.sh

exit
