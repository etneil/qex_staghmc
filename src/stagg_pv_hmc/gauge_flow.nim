#[ ~~~~ Import necessary modules ~~~~ ]#

import qex # QEX
import gauge # Gauge field
import times # Timing
import macros # Useful macros
import os # For operating system-specific tasks
import streams, parsexml, strutils # For parsing XML
import parseopt # For parsing command line arguments
import tables # For organizing data
import sequtils # For dealing with sequences
import math # Basic mathematical operations
import gauge/wflow # For intermediate measurements

#[ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Authors: Curtis Taylor Peterson, James Osborn, Xiaoyong Jin

Description:

   Gauge flow measurements. Currently only uses Wilson flow. Other
   flows/measurements to be added in the future.

Credits:

   Thank you to James Osborn Xiaoyong Jin for developing QEX and helping
   develop this program.

   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ]#

#[ ~~~~ Initialize QEX ~~~~ ]#

# Initialize QEX
qexinit()

# Print start date
echo "\nStart: ", now().utc

#[ ~~~~ Initialize info for whole file ~~~~ ]#

# Initialize attribute name
var attrName = ""

# Initialize attribute value
var attrVal = ""

# Define integer parameters
var int_prms = {"Ns" : 0, "Nt" : 0, "f_munu_loop" : 0}.toTable

# Define float parameters
var flt_prms = {"dt" : 0.1, "t_max" : 0.0}.toTable

# Initialize starting trajectory
var start_config = 0

# Initialize ending trajectory
var end_config = 0

# Initialize filename
var fn = "checkpoint"

# Initialize xml file
var xml_file = ""

# Initialize rank geometry
var rank_geom = @[1, 1, 1, 1]

#[ ~~~~ Parallel information ~~~~ ]#

# Print number of ranks
echo "# ranks: ", nRanks

# Print number of threads
threads: echo "# threads: ", numThreads

#[ ~~~~ For timing ~~~~ ]#

proc ticc(): float =
   # Return t0
   result = cpuTime()

proc tocc(message: string, t0: float) =
   # Print timing
   echo message, " ", cpuTime() - t0, "s"

#[ ~~~~ Functions for gauge measurements ~~~~ ]#

#[ For reunitarization ]#
proc reunit(g: auto) =
   # Start timer
   tic()

   # Create separator
   echo ""

   # Start thread block and reunitarize
   threads:
      let d = g.checkSU
      threadBarrier()
      echo "unitary deviation avg: ",d.avg," max: ",d.max
      g.projectSU
      threadBarrier()
      let dd = g.checkSU
      echo "new unitary deviation avg: ",dd.avg," max: ",dd.max

   # End timer
   toc("reunit")

#[ For measuring plaquette ]#
proc meas_plaq(g: auto): auto =
   # Start timer
   tic()

   # Calculate plaquette
   let
      pl = g.plaq
      nl = pl.len div 2
      ps = pl[0..<nl].sum * 2.0
      pt = pl[nl..^1].sum * 2.0

   # End timer
   toc("plaq")

   # Return result
   result = (ps, pt)

#[ For measuring polyakov loop ]#
proc meas_ploop(g: auto): auto =
   # Start timer
   tic()

   # Calculate Polyakov loop
   let pg = g[0].l.physGeom
   var pl = newseq[typeof(g.wline @[1])](pg.len)
   for i in 0..<pg.len:
      pl[i] = g.wline repeat(i+1, pg[i])
   let
      pls = pl[0..^2].sum / float(pl.len-1)
      plt = pl[^1]

   # End timer
   toc("ploop")

   # Return Polyakov loop
   result = (pls, plt)

#[ ~~~~ Functions for initialization ~~~~ ]#

#[ For reading flow parameters ]#
proc initialize_gauge_field_and_params(): auto = 
   #[ ~~~~ Read command line and XML information ~~~~ ]#

   # Get initial time
   let t0 = ticc()

   # Create XML parser
   var x: XmlParser

   # Print out separator
   echo "\n ~~~~ Command line and XML information  ~~~~\n"

   # Create parser for command line options
   var cm_opts = initOptParser()

   # Cycle through command line arguments
   while true:
      # Go to next option
      cm_opts.next()

      # Start case
      case cm_opts.kind
         of cmdEnd: break # Exit of options
         of cmdShortOption, cmdLongOption, cmdArgument:
            
            # Check if starting config.
            if cm_opts.key == "start_config":
               # Set ending config.
               start_config = parseInt(cm_opts.val)

               # Print ending config.
               echo "start config: " & cm_opts.val

            # Check if ending config.
            if cm_opts.key == "end_config":
               # Set ending trajectory
               end_config = parseInt(cm_opts.val)

               # Print ending config.
               echo "end config: " & cm_opts.val

            # Check if base file name
            if cm_opts.key == "filename":
               # Set filename
               fn = cm_opts.val

               # Print filename
               echo "flowing gauge file: " & cm_opts.val
           
            # Check if xml file
            if cm_opts.key == "xml":
               # Set xml file
               xml_file = cm_opts.val

               # Tell user where information is being read from
               echo "XML file: " & cm_opts.val     

            # Check if MPI layout for physical geometry
            if cm_opts.key == "rank_geom":
               # Split geometry string
               let gm_str_splt = cm_opts.val.split({'.'})

               # Cycle through entries in rank geometry
               for ind in 0..<gm_str_splt.len:
                  # Fill rank geometry string
                  rank_geom[ind] = parseInt(gm_str_splt[ind])

   # Define xml filename
   var file_stream = newFileStream(xml_file, fmRead)

   # Check if file exists
   if file_stream == nil:
      # If file does not exist, exit
      quit("Cannot open " & xml_file)
   else:
      # Open file
      open(x, file_stream, xml_file)

      # Cycle through data
      while true:
         # Go to next option
         x.next()

         # Start case
         case x.kind
            # Do checks
            of xmlElementStart: # If element name
               # Define name
               attrName = x.elementName
            of xmlCharData: # If element attribute
               # Define value
               attrVal = x.charData

               # Check if attribute of parameter tables
               if int_prms.hasKey(attrName):
                  # Save parameter
                  int_prms[attrName] = parseInt(attrVal)
               elif flt_prms.hasKey(attrName):
                  # Save parameter
                  flt_prms[attrName] = parseFloat(attrVal)

               # Print variable
               echo attrName & ": " & attrVal

            of xmlEof: break # If end of file, exit
            else: discard # Otherwise, do nothing

      # Close
      x.close()

   #[ ~~~~ Initialize lattice and gauge field ~~~~ ]#
   
   # Define various variables for gauge action
   let
      # Define lattice
      lat = intSeqParam("lat", @[int_prms["Ns"], int_prms["Ns"],
                                 int_prms["Ns"], int_prms["Nt"]])

      # Define new lattice layout
      lo = lat.newLayout(rank_geom)

   # Create new gauge
   var g = lo.newgauge

   #[ ~~~~ Return gauge field ~~~~ ]#
   # Return result
   result = g

#[ ~~~~ Initialize gauge field ~~~~ ]#

# Read in appropriate information and initialize gauge field
var g = initialize_gauge_field_and_params()

#[ ~~~~ Functions for gauge field IO ~~~~ ]#

#[ For reading in gauge flows ]#
proc read_gauge_file(gaugefile: string) =
   # Check if gauge field file exists
   if fileExists(gaugefile):
      # Start timer
      tic("Loading gauge file")

      # Check if gauge file can be read
      if 0 != g.loadGauge gaugefile:
         # If not, throw qex error
         qexError "failed to load gauge file: ", gaugefile

      # Set output to qexLog
      qexLog "loaded gauge from file: ", gaugefile," secs: ", getElapsedTime()

      # End timer
      toc("read")

      # Reunitarize
      g.reunit

#[ ~~~~ Functions for gauge flow ~~~~ ]#

#[ For calculating flowed measurements ]#
proc EQ(gauge: auto, loop: int): auto =
   # Calculate measurements
   let
      # Get loop
      f = gauge.fmunu loop

      # Calculate Yang-Mills density
      (es, et) = f.densityE

      # Calculate topological charge
      q = f.topoQ

      # Measure Plaquette
      (ss, st) = gauge.meas_plaq()

      # Measure Polyakov loop
      (pls, plt) = gauge.meas_ploop()

   # Return Yang-Mills density and topology
   return (es, et, ss, st, q, pls, plt)

#[ For flow and flow measurements ]#
proc wflow(flowed_gauge: auto) =
   # Start timer
   tic()

   # Get initial time
   let t0 = ticc()

   # Initialize measurements
   let (es, et, ss, st, q, pls, plt) = flowed_gauge.EQ int_prms["f_munu_loop"]

   # Define default string
   var def_str = "WFLOW t, es, et, ss, st, q, pls, plt: "

   # Print initial measurements
   echo def_str, 0.0, " ", es, " ", et, " ", ss, " ", st, " ", q, " ", pls, " ", plt

   # Start flow loop
   flowed_gauge.gaugeFlow(flt_prms["dt"]):
      # Calculate measurement
      let (es, et, ss, st, q, pls, plt) = flowed_gauge.EQ int_prms["f_munu_loop"]

      # Print result of measurement
      echo def_str, wflowT, " ", es, " ", et, " ", ss, " ", st, " ", q, " ", pls, " ", plt 

      # Breaking condition
      if (flt_prms["t_max"] > 0) and (wflowT > flt_prms["t_max"]):
         # Exit flow loop
         break

   # End timer
   toc("Wflow")

   # Print timing to output file
   tocc("Wilson flow:", t0)

#[ ~~~~ Perform gauge flow ~~~~ ]#

#[ Cycle through configurations ]#
for config in start_config..<end_config + 1:

   #[ Take care of initial information ]#

   # Get initial time for config
   let config_time = ticc()
   
   # Tell user what config. that you're on
   echo "\n~~~~ Flowing config. # " & intToStr(config) & " ~~~~\n"

   #[ Read in appropriate gauge field ]#

   # Name gauge file
   let filename = fn & "_" & intToStr(config) & ".lat"

   # Load gauge field
   read_gauge_file(filename)

   #[ Flow gauge field ]#

   # Do Wilson flow
   g.wflow()

   #[ Finalize this gauge flow ]#

   # Print out timing for this flow
   tocc("Flow for config. # " & intToStr(config) & ":", config_time)

# Print end date
echo "\nEnd: ", now().utc, "\n" 

# Finalize QEX
qexfinalize()