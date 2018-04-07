#!/usr/bin/perl
use File::Spec;
use File::Copy 'move';
use File::Path 'rmtree';
use File::Basename 'fileparse';

use lib "./lib";
use Amazon::S3;

# MAC: You need to have X11 SDk installed and the gcc etc.
# The gcc is installed from Finder--HD--Applications--Installers--XCode tools--Developer.mpkg
# The X11 I installed from http://chemistry.ucsc.edu/%7Ewgscott/temp/x11sdk_10.3.dmg.gz
# Which I found at http://www.chemistry.ucsc.edu/~wgscott/xtal/page1.html
#

#############################################################
#
# This is a master build script for zlab
# It will setup a Windows, Linux, or Mac machine for a particular zlab configuration 
#
# It has a comprehensive testing system to test each SDK
# for correct installtion and configuration
#
# PRE-REQUISITES:
#  Perl.        http://www.perl.com/download.csp
#
# USAGE:
#  perl zlabbuild.pl
#
#############################################################

# SAVE users path
$userPath = $ENV{PATH};

# SET Verbose for debug tracing
$verbose = 0;

# FIND platform
$platform = determinePlatform();
my $svnRev = svnRevision();
	# In the case we're using git, the YYYYMMDD date value will be returned for svnRev.
	# This can be used as a buildstamp e.g. version Major.Minor.svnRev

# FIND the critical folders, @TODO create them if not found
$sdkDir    = findDirectory( qw^../sdkpub^ );
$sdkPrvDir = findDirectory( qw^../sdkprv^ );
$zbslibDir = findDirectory( qw^../zbslib^ );
$zlabDir   = findDirectory( qw^../zlabcore^ );

$buildDir  = "${zlabDir}/../build";
mkdir( $buildDir );


if( ! -e "$zlabDir/main.cpp" ) {
	die( "Can't find main.cpp in $zlabDir" );
}

# TEST the compiler
# testCompiler( $platform );
  # I moved this after configLoad() because I want a config to be able to affect 
  # which compiler settings are used (e.g. build64bit on windows), so testCompiler()
  # is called each time the main menu refreshes based on a user choice.  (tfb)

# SETUP the sdk information and check on their availability
$sdkBuildScript = "$sdkDir/sdkcore/sdkbuild.pl";
unless (-e $sdkBuildScript) {
	die "Cannot find sdk build script $sdkBuildScript";
} 

unless ($return = do $sdkBuildScript) {
	die "ERROR - couldn't parse $sdkBuildScript: $@" if $@;
	die "ERROR - couldn't do $sdkBuildScript: $!" unless defined $return;
	die "ERROR - couldn't run $sdkBuildScript" unless $return;
}

sdkSetup();

%pluginInterface = ();
	# This contains 'gui', or 'console' for each plugin


####################################################################################################
#
# CONFIGURATIONS
#
####################################################################################################

@configNames = ( 'none', 'kin_pro', 'kin_pro_py', 'kin_dev', 'kin_web', 'stopflow', 'stopflow_zfit' );

#
# Config: Kin
#
sub config_kin_pro {
	my( $setup, $dstDir ) = @_;
	if( $setup ) {
		do( "$zlabDir/../plug_kintek/_kin/kinbuild.pl" ) || die "Unable to find _kin/kinbuild.pl";
		$configInterface = 'gui';
		@configPlugins = ( 'kin' );
		$svnRev = svnRevision( $configPluginPaths{ '_kin' } ); 
		@configDefines = ( 'KIN', 'KIN_PRO', 'NO_GSL', "TITLE=\"KinTek Global Kinetic Explorer Version $kinVersionMajor.$kinVersionMinor.$svnRev. Copyright Kenneth A. Johnson and KinTek Corporation\"" );
		$configIconWin32 = '../plug_kintek/_kin/kin.ico';
		$configIconMacosx = '../plug_kintek/_kin/kin.icns';
		$configPackageName = 'KinTek_Explorer';
		$configPackageTo = "$configPackageName";
		@configExtraMenu = @config_kin_extraMenu;
	}
	else {
		kinDataCopy( $dstDir, 0 );
	}
}

sub config_kin_pro_py {
	my( $setup, $dstDir ) = @_;
	if( $setup ) {
		do( "$zlabDir/../plug_kintek/_kin/kinbuild.pl" ) || die "Unable to find _kin/kinbuild.pl";
		$configInterface = 'gui';
		@configPlugins = ( 'kin' );
		$svnRev = svnRevision( $configPluginPaths{ '_kin' } ); 
		@configDefines = ( 'KIN', 'KIN_PRO', 'NO_GSL', "TITLE=\"KinTek Global Kinetic Explorer Version $kinVersionMajor.$kinVersionMinor.$svnRev. Copyright Kenneth A. Johnson and KinTek Corporation\"" );
		$configIconWin32 = '../plug_kintek/_kin/kin.ico';
		$configIconMacosx = '../plug_kintek/_kin/kin.icns';
		$configPackageName = 'KinTek_Explorer_Py';
		$configPackageTo = 'KinTek_Explorer';
		@configExtraMenu = @config_kin_extraMenu;
	}
	else {
		kinDataCopy( $dstDir, 1 );
	}
}

sub config_kin_dev {
	my( $setup, $dstDir ) = @_;
	if( $setup ) {
		do( "$zlabDir/../plug_kintek/_kin/kinbuild.pl" ) || die "Unable to find _kin/kinbuild.pl";
		$configInterface = 'gui';
		@configPlugins = ( 'kin', 'kingsl' );
		@configDefines = ( 'KIN' );
		$svnRev = svnRevision( $configPluginPaths{ '_kin' } ); 
		@configDefines = ( 'KIN', 'KIN_DEV', "TITLE=\"KinTek Global Kinetic Explorer DEV Version $kinVersionMajor.$kinVersionMinor.$svnRev. Copyright Kenneth A. Johnson and KinTek Corporation\"" );
		$configIconWin32 = '../plug_kintek/_kin/kin.ico';
		$configIconMacosx = '../plug_kintek/_kin/kin.icns';
		$configPackageName = 'KinTek_Explorer_Dev';
		$configPackageTo = "$configPackageName";
		@configExtraMenu = @config_kin_extraMenu;
	}
	else {
		kinDataCopy( $dstDir, 0 );
	}
}

sub config_kin_web {
	my( $setup, $dstDir ) = @_;
	if( $setup ) {
		do( "$zlabDir/../plug_kintek/_kin/kinbuild.pl" ) || die "Unable to find _kin/kinbuild.pl";
		$configInterface = 'console';
		@configPlugins = ( 'kinweb' );
		@configDefines = ( 'KIN' );
		$svnRev = svnRevision( $configPluginPaths{ '_kin' } ); 
		@configDefines = ( 'KIN', 'KIN_PRO', 'NO_GSL', 'KIN_WEB', "TITLE=\"KinTek Global Kinetic Explorer WEB Version $kinVersionMajor.$kinVersionMinor.$svnRev. Copyright Kenneth A. Johnson and KinTek Corporation\"" );
		$configIconWin32 = '../plug_kintek/_kin/kin.ico';
		$configIconMacosx = '../plug_kintek/_kin/kin.icns';
		$configPackageName = 'KinTek_Explorer_Web';
		$configPackageTo = "$configPackageName";
		@configExtraMenu = @config_kin_extraMenu;
	}
	else {
		kinDataCopyWeb( $dstDir );
	}	
}

sub options_kin {
	# Prints program configuration options specific to _kin to the options.cfg file
	# which ships with the software.
	#
	# @TODO? It would be nicer for these options to live in a file under _kin somewhere
	# and get copied.
	my ($file) = @_;
	print $file "Kin_modelPath = \"./models/*.mec\"\n";
	print $file "Kin_rawdataPath = \"./rawData/*.txt\"\n";
	print $file "Kin_outputFitPath = \"./output/*.txt\"\n";
	print $file "Kin_outputSimPath = \"./output/*.txt\"\n";
	print $file "Kin_outputDataPath = \"./output/*.txt\"\n";
	print $file "fitspaceSolid = 1\n";
	print $file "exportSim_fontserif_default = 0\n";
	print $file "exportSim_font_size_default = 11\n";
	print $file "exportSim_linewidth_default = 2\n";
	print $file "exportSim_line_brightness_default = .7\n";
	print $file "exportSim_marker_size_default = 2\n";
	print $file "exportSim_data_lines_default = 0\n";
	print $file "exportWavelen_time_max_default = 10000.0\n";
	print $file "exportWavelen_x_label_default = Wavelength (nm)\n";
	print $file "exportWavelen_z_label_default = Absorbance\n";
	print $file "exportData2_x_label_default = Time (s)\n";
	print $file "exportData2_y_label_default = Concentration (uM)\n";
	print $file "exportData3_x_label_default = Wavelength (nm)\n";
	print $file "exportData3_y_label_default = Time (s)\n";
	print $file "exportData3_z_label_default = Absorbance\n";
	print $file "exportRateVsConcFit_x_label_default = Concentration (uM)\n";
	print $file "exportRateVsConcFit_y_label_default = Rate\n";
	print $file "exportAmpVsConcFit_x_label_default = Concentration (uM)\n";
	print $file "exportAmpVsConcFit_y_label_default = Amplitude\n";
}


#
# Config: Stopflow
#
sub config_stopflow {
	# Normal StopFlow
	my( $setup, $dstDir ) = @_;
	if( $setup ) {
		do( "$zlabDir/../plug_kintek/_stopflow/stopflowbuild.pl" ) || die "Unable to find _stopflow/stopflowbuild.pl";
		$configInterface = 'gui';
		@configPlugins = ( 'stopflow' );
        # actual title is set at runtime, but set something so it never appears as 'zlab'
		@configDefines = ( 'STOPFLOW', "TITLE=\"Stopflow\"" );
		$configIconWin32 = '../plug_kintek/_stopflow/stopflow.ico';
		$configPackageName = "KinTek_Stopflow_$svnRev";
		$configPackageTo = "$configPackageName";
		stopflowDllCopy( $zlabDir, $buildDir );
	}
	else {
		stopflowDataCopy( $dstDir );
	}
}

sub config_stopflow_zfit {
	# StopFlow with zfitter added for experimentation
	my( $setup, $dstDir ) = @_;
	if( $setup ) {
		do( "$zlabDir/../plug_kintek/_stopflow/stopflowbuild.pl" ) || die "Unable to find _stopflow/stopflowbuild.pl";
		$configInterface = 'gui';
		@configPlugins = ( 'stopflow', 'sfzfit' );
        # actual title is set at runtime, but set something so it never appears as 'zlab'
		@configDefines = ( 'STOPFLOW', "TITLE=\"Stopflow\"" );
		$configIconWin32 = '../plug_kintek/_stopflow/stopflow.ico';
		$configPackageName = "KinTek_StopflowZfit_$svnRev";
		$configPackageTo = "$configPackageName";
		stopflowDllCopy( $zlabDir, $buildDir );
	}
	else {
		stopflowDataCopy( $dstDir );
	}
}

sub configClear {
	$configName = 'none';
	@configDefines = ();
	$configIcon = '';
	$configInterface = 'gui';
	@configPlugins = ();
	@configUsedSDKs = ();
	@configUsedFiles = ();
	@configSearchPath = ();
	$configPackageName = '';
	$configPackageTo = '';
	@configExtraMenu = ();
	%configPluginPaths = ();
	@configPluginDirSpec = ();
}

sub configSave {
	open( FILE, ">$buildDir/zlabbuild.cfg" );
	print FILE "interface = '$configInterface'\n";
	print FILE "plugins = '" . (join ",", @configPlugins) . "'\n";
	print FILE "configName = '$configName'\n";
	close( FILE );
}

sub configLoad {
	open( FILE, "$buildDir/zlabbuild.cfg" );
	while( <FILE> ) {
		chomp;
		if( /interface = '(.*)'/ ) {
			$configInterface = $1;
		}
		if( /plugins = '(.*)'/ ) {
			my $mods = $1;
			@configPlugins = split( /,/, $mods );
		}
		if( /configName = '(.*)'/ ) {
			$configName = $1;
		}
	}
	close( FILE );
}

sub createMakeFileCleanBuildPackage() {
	@packagesCreated = ();

	$compilerOK = testCompiler( $platform );
	if( $compilerOK ne "OK" ) {
		die $compilerOK;
	}

	my $ret = createMakeFileAndOptionallyBuild( 1 );
	if( ! $ret ) {
		print "FAILED.\n";
	}
	else {
		packageZlab();
	}
}


####################################################################################################
#
# MAIN MENU
#
####################################################################################################

configClear();
if( $ARGV[0] ) {
	# if valid config name spec'd from command line, select it, 
	# build required sdks, and package.  (for automated builds)
	if( defined &{'config_' . $ARGV[0]} ) {
		pushCwd( $buildDir );
		$configName = $ARGV[0];
		&{'config_' . $configName}( 1 );
		analyzeUsedFiles();
		print "Performing clean build+package for configuration \"$configName\"...\n";
		if( !$ARGV[1] || $ARGV[1] ne "nosdk" ) {
			&compileAndTestSDKsInOrder( @configUsedSDKs );
		}
		createMakeFileCleanBuildPackage();
		exit;
	}
	elsif( $ARGV[0] eq 'kintek' ) {
		#		
		# Build & package multiple configurations, only building the SDKs the first time.
		#
		pushCwd( $buildDir );

		my $begin = time();

		my $buildSDKs = !$ARGV[1] || $ARGV[1] ne "nosdk";
		printf "Building multiple configs for KinTek Explorer.  Build SDKs: %s\n",  $buildSDKs ? "Yes" : "No";

		my @uploadFiles = ();
		my @configs = qw( kin_pro_py kin_pro );

		foreach( @configs ) {
			configClear();
			$configName = $_;
			print "\n***\n***  clean build+package for configuration \"$configName\"...\n***\n";
			&{'config_' . $configName}( 1 );
			analyzeUsedFiles();
			if( $buildSDKs ) {
				&compileAndTestSDKsInOrder( @configUsedSDKs );
				$buildSDKs = 0;
			}
			createMakeFileCleanBuildPackage();
				# this resets and then populates the @packagesCreated list.
			push @uploadFiles, @packagesCreated;
		}	

		my $kintekVer = "$kinVersionMajor.$kinVersionMinor.$svnRev";
		my $platformDesc = platformDescription();
		my $verFile = "KinTekExplorerVersion_$platformDesc.txt";
		unlink $verFile or warn "Can't unlink $verFile";
		open(my $fh, '>', $verFile) or die "Can't open $verFile";
		print $fh "$kintekVer\n";
		close $fh;
		push @uploadFiles, $verFile;

		#
		# Put built apps on S3
		#
		print "\n***\n***  uploading builds to S3 ...\n***\n";
		foreach my $f ( @uploadFiles ) {
			my $start = time();
			print( "Uploading $f ... " );
			kinUploadToS3( $f );
			my $elapsed = time() - $start;
			print( "$elapsed seconds.\n" );
		}

		my $total = (time() - $begin) / 60.0;
		print "\nKinTek Explorer $kintekVer : done. ($total minutes)\n";
		exit;
	}
	else {
		print "   ** Unknown configuration specified: $ARGV[0]\n";
		exit;
	}
}

cls();
configLoad();
if( defined &{'config_' . $configName} ) {
	# RUN the config setup if there is one
	&{'config_' . $configName}( 1 );
}
print "Analyzing files...\n";
pushCwd( $buildDir );
analyzeUsedFiles();

$devVersion="unknown";
$winSdkDir="unknown";

while( 1 ) {
	cls();

	# TEST compiler for current configuration
	my $platformDesc = platformDescription();
	testCompiler( $platform );

	# PRINT out the current configuration	
	print "CONFIGURATION\n";
	print "----------------------------------------------------------------\n";
	print "  Selected Config Name:\n";
	print "    $configName\n";
	print "  Platform: $platformDesc (ver=$devVersion)\n";
	print "  Directories:\n";
	print "    sdkDir   : $sdkDir\n";
	print "    zbslibDir: $zbslibDir\n";
	print "    zlabDir  : $zlabDir\n";
	print "    buildDir : $buildDir\n";
	print "    devDir   : $devDir\n";
	print "    winSdkDir: $winSdkDir\n";
	print "    INCLUDE  : $ENV{INCLUDE}\n";
	print "    LIB      : $ENV{LIB}\n";
	print "  Selected Plugins:\n";
	print "    " . join( ", ", sort( @configPlugins ) ) . "\n";
	printf "  Interface: $configInterface\n";
	if( @configUsedSDKs > 0 ) {
		print "  SDKs required for currently selected plugins:\n";
		map { printf "    %-12s @{$sdkHash{$_}->{platforms}}\n", $_ } sort( @configUsedSDKs );
	}
	print  " \n\n";

	# RUN the config setup if there is one
	if( defined &{'config_' . $configName} ) {
		&{'config_' . $configName}( 1 );
	}
	
	#
	# MAIN MENU
	#
	print "MAIN MENU\n";
	print "----------------------------------------------------------------\n";
	menu(
		"Quit" => sub {
			exit;
		},

		"Walk through first time setup" => sub {
			cls();
			print "Zlab is a generic framework for writing interactive C/C++ OpenGL-based\n";
			print "code that cross compiles on Windows, Linux, and Mac.  The Perl script \n";
			print "you are currently running is used to make all the various makefiles,\n";
			print "run tests on the SDKs and developement tools, and package the final binaries.\n";
			print "\n";
			print "First-time setup checklist:\n";

			print  "  1. Confirm that you have subversion (svn) version control.\n";
			my $svnOK = checkForSvn();
			printf "     (%s) Svn was %sfound.", $svnOK ? "OK" : "FAIL", $svnOK ? "" : "NOT ";
			if( ! $svnOK ) {
				print  "\n";
				print  "          TO RESOLVE THIS PROBLEM:\n";
				print  "          * Download and install subversion from\n";
				print  "            http://subversion.tigris.org/project_packages.html\n";

			}

			print "\n\n";
			print  "  2. Confirm that you have the development environment.\n";
			my $compilerOK = testCompiler();
			printf "     (%s) Compiler was %sfound %s", $compilerOK ? "OK" : "FAIL", $compilerOK ? "" : "NOT ", $compilerOK ? "in $devDir" : "";
			if( ! $compilerOK ) {
				print  "\n";
				print  "          TO RESOLVE THIS PROBLEM:\n";
				print  "          * On Windows, install MSDEV 6.0. Contact zack AT mine-control.com\n";
				print  "            if you don't know where to get this.\n";
				print  "          * On Linux or Mac, install the g++ package with your package manager.\n";
			}

			print "\n\n";
			print  "  3. Use svn to 'checkout' the three principal code directories.\n";
			printf "     (%s) sdkpub directory was %sfound %s", $sdkDir ? "OK" : "FAIL", $sdkDir ? "" : "NOT ", $sdkDir ? "in $sdkDir" : "";
			if( ! $sdkDir ) {
				print  "\n";
				print  "          TO RESOLVE THIS PROBLEM:\n";
				print  "          * Make a root folder such as '/zlabdev'\n";
				print  "            In that folder, run:\n";
				print  "            'svn co http://svn.icmb.utexas.edu/svnrepos/sdkpub'\n";
			}


			print "\n";
			printf "     (%s) zbslib directory was %sfound %s", $zbslibDir ? "OK" : "FAIL", $zbslibDir ? "" : "NOT ", $zbslibDir ? "in $zbslibDir" : "";
			if( ! $zbslibDir ) {
				print  "\n";
				print  "          TO RESOLVE THIS PROBLEM:\n";
				print  "          * Make a root folder such as '/zlabdev'\n";
				print  "            In that folder, run:\n";
				print  "            'svn co http://svn.icmb.utexas.edu/svnrepos/zbslib'\n";
			}

			print "\n";
			printf "     (%s) zlab   directory was %sfound %s", $zlabDir ? "OK" : "FAIL", $zlabDir ? "" : "NOT ", $zlabDir ? "in $zlabDir" : "";
			if( ! $zlabDir ) {
				print  "\n";
				print  "          TO RESOLVE THIS PROBLEM:\n";
				print  "          * Make a root folder such as '/zlabdev'\n";
				print  "            In that folder, run:\n";
				print  "            'svn co http://svn.icmb.utexas.edu/svnrepos/zlab'\n";
			}

			print "\n\n";
			print  "  4. When everything above is OK, return to the main menu and\n";
			print  "     either choose an existing 'config' or select individual plugins\n";
			print  "     to include in your project.  This Perl script will then compute which\n";
			print  "     source files and SDKs are needed and will construct makefiles and\n";
			print  "     development project files as needed.  Before the first time you\n";
			print  "     create a makefile, choose 'Compile and test all necessary SDKs'\n";
			print  "     on the main menu.  After this is successful, you can either\n";
			print  "     'Create makefile only' and then compile externally or you can\n";
			print  "     'Create makefile, clean, build, package' which will produce binaries.\n";

			print "\n\n";
			print "Press ENTER to return to Main Menu.";
			<STDIN>;
		},

		"Select a named config" => sub {
			# CLEAR all the current plugins
			configClear();

			# MAKE a hash from the currently selected plugins so that they will show up in the menu
			my %configs;
			foreach( @configNames ) {
				# @TODO: isvalid fns for named configs as prereq for inclusion?
				if( ( $_ eq 'none' ) ||
					( $_ =~ /kin_/ && -d '../plug_kintek' ) || 
					( $_ =~ /stopflow/ && -d '../plug_kintek' ) ) {
					$configs{$_} = 0;
				}
			}

			%configs = radioMenu( %configs );
			map { $configName = $_ if $configs{$_} } keys %configs;

			if( defined &{'config_' . $configName} ) {
				&{'config_' . $configName}( 1 );
			}
			configSave();

			print "Analyzing files...\n";
			analyzeUsedFiles();
		},

		"Select the plugins" => sub {
			# MAKE a hash from the currently selected plugins so that they will show up in the menu
			my %currentlySelectedPlugins;
			foreach( @configPlugins ) {
				$currentlySelectedPlugins{$_} = 1;
			}

			pluginSelectMenu();
			print "Analyzing files...\n";
			analyzeUsedFiles();
			configSave();
		},

		"Compile and test all necessary SDKs (all SDKS must be built before build)" => sub {
			&compileAndTestSDKsInOrder( @configUsedSDKs );
			print "Press ENTER key to continue.\n";
			<STDIN>;
		},

		"Compile and test a specific SDK (for testing specific problems)" => sub {
			$compilerOK = testCompiler( $platform );
			if( $compilerOK ne "OK" ) {
				die $compilerOK;
			}

			my %sdks;
			foreach( keys %sdkHash ) {
				if( defined $sdkHash{$_}{test} ) {
					$sdks{$_} = 0;
				}
			}

			%sdks = radioMenu( %sdks );
			my $selected;
			map { $selected = $_ if $sdks{$_} } keys %sdks;
			if( $selected ) {
				print "Testing $selected ... ";
				&{$sdkHash{$selected}{test}};
				print "Press ENTER key to continue.\n";
				<STDIN>;
			}
		},

		"Create makefile only (In windows open .vcproj in VC and build manually)" => sub {
			createMakeFileAndOptionallyBuild( 0 );
		},

		"Create makefile, clean, build, and package (beta, testing only)" => sub {
			createMakeFileCleanBuildPackage();
			print "Press ENTER key to continue.\n";
			<STDIN>;
		},

		@configExtraMenu,

	);
}

sub pluginSelectMenu {
	my %configPluginsHash;
	map{ $configPluginsHash{$_} = 1 } @configPlugins;
	my @pluginFromCode;

	while( 1 ) {
		cls();
		printf "   0) Exit Menu\n";
		print "\n";
		my $i = 1;
		print "-- GUI-based plugins (more than one may be selected) --------------\n";
		foreach my $p( sort keys %pluginInterface ) {
			if( $pluginInterface{$p} eq 'gui' ) {
				printf "  %2d) (%s) %-10s = %s\n", $i, $configPluginsHash{$p} ? '+' : ' ', $p, $pluginDescription{$p};
				$pluginFromCode[$i] = $p;
				$i++;
			}
		}

		printf "  %2d) ALL\n", $i;
		my $allCode = $i;
		$i++;

		print "\n";
		my $firstConsole = $i;
		print "-- Console-based plugins (only one can be selected) ---------------\n";
		foreach my $p( sort keys %pluginInterface ) {
			if( $pluginInterface{$p} eq 'console' ) {
				printf "  %2d) (%s) %-10s = %s\n", $i, $configPluginsHash{$p} ? '*' : ' ', $p, $pluginDescription{$p};
				$pluginFromCode[$i] = $p;
				$i++;
			}
		}
		print "\n";

		my $which = <STDIN>;

		last if( $which == 0 );
		if( $which >= 1 && $which < $i ) {
			# Selected a console plugin, only one allowed
			if( $which >= $firstConsole ) {
				# CLEAR all the selections
				map{ $configPluginsHash{$_} = 0 } keys %configPluginsHash;
				$configPluginsHash{ $pluginFromCode[$which] } = 1;
			}
			elsif( $which == $allCode ) {
				map{ $configPluginsHash{$_} = 1 if $pluginInterface{$_} eq 'gui' } keys %pluginInterface;
			}
			else {
				# CLEAR all the console selections
				map{ $configPluginsHash{$_} = 0 if $pluginInterface{$_} eq 'console' } keys %configPluginsHash;
				$configPluginsHash{ $pluginFromCode[$which] } = ! $configPluginsHash{ $pluginFromCode[$which] };
			}
		}
	}

	@configPlugins = ();
	map{ push( @configPlugins, $_) if $configPluginsHash{$_} } keys %configPluginsHash;
}

####################################################################################################
#
# ANALYZE FILES
#
####################################################################################################

sub analyzeUsedFiles {
	# This function scans the directories for plugins and 
	# does a full analysis of all files to determine which files and SDK are needed

	#
	# SCAN plugins
	#

		# SEARCH all of the folders up one level that start with plug_
		# Any directory under those folders that starts with underscore is assumed
		# to be a plugin.

		# CLEAR the pluginInterface & pluginDescription globals
		%pluginInterface = ();
		%pluginDescription = ();

		#
		# SEARCH for the plug_ folders which can contain subfolders of plugins, push @pluginFiles for each one found
		#
		my @plugDirs = ();
		my @pluginFiles = ();
		foreach $plugDir ( <../plug_*> ) {
			if( -d $plugDir ) {
				print "found plugDir $plugDir\n" if( $verbose );
				push @configSearchPath, $plugDir;

				foreach $subplugDir ( <$plugDir/_*> ) {
					if( -d $subplugDir ) {
						print "found subplugDir $subplugDir\n" if( $verbose );
						my $pluginName = (fparse($subplugDir))[2];
						my $pluginFilename = "$subplugDir/$pluginName.cpp";
						if( -f $pluginFilename ) {
							print "found plugin file $pluginFilename\n" if( $verbose );
							push @pluginFiles, $pluginFilename;
							push @plugDirs, $subplugDir;
							push @configSearchPath, $subplugDir;
							$configPluginPaths{ $pluginName } = "./" . $subplugDir;
						}
					}
				}
			}
		}

		# At this point, the @pluginFiles has the list of every potential
		# plugin from all the plug_ paths

		#
		# READ the ZBS headers for every plugin and accumulate data
		#

		my $pluginFilename;
		foreach $pluginFilename( @pluginFiles ) {

			my %hash = zbsModuleReadRecord( $pluginFilename );

			$pluginFilename =~ m!(.*/)?_(.*)\.c!;
			my $pluginName = $2;

			#
			chomp $hash{DESCRIPTION};
			$hash{DESCRIPTION} =~ tr/\n\r/ /;
			$pluginDescription{$pluginName} = $hash{DESCRIPTION};

			if( $hash{INTERFACE}->[0] ) {
				$pluginInterface{$pluginName} = $hash{INTERFACE}->[0];
			}
			else {
				# DETERMINE the interface by scanning the file
				open( FILE, "$hash{FILENAME}" );
				my @funcs;
				while( <FILE> ) {
					$funcs[0] = 1 if( /^\s*void render/ );
					$funcs[1] = 1 if( /^\s*void startup/ );
					$funcs[2] = 1 if( /^\s*void shutdown/ );
					$funcs[3] = 1 if( /^\s*(void|int)\s*main/ );
				}
				close( FILE );
				if( $funcs[0] && $funcs[1] && $funcs[2] ) {
					$pluginInterface{$pluginName} = 'gui';
				}
				elsif( $funcs[3] ) {
					$pluginInterface{$pluginName} = 'console';
				}
				else {
					print "*** $pluginName has an unknown interface\n";
					$pluginInterface{$pluginName} = 'unknown';
				}
			}
			print "pluginInterface for $pluginName = $pluginInterface{$pluginName}\n" if( $verbose );
		}

	#
	# SCAN all files in zbslib and recursively in the plugins for any modules
	#


	#
	# CLEAR current
	#
	undef %zbsModuleRecords;
	undef %zbsModuleByHeader;

	
	my @searchDirs = ( $zbslibDir, $zlabDir );
	foreach( @plugDirs ) {
		push @searchDirs, recurseDir( $_ );
	}

	print "searchDirs = " . join "; ", @searchDirs if( $verbose );

	foreach my $searchDir( @searchDirs ) {
		my $dir = $searchDir;
		if( $dir !~ m#/$# ) {
			$dir .= '/';
		}

		my @glob = ( <${dir}*.cpp>, <${dir}*.c>, <${dir}*.h> );
		foreach my $file( @glob ) {
			my %hash = zbsModuleReadRecord( $file );

			my $moduleName = ( (fparse( $file ))[2] . (fparse( $file ))[3] );

			$zbsModuleRecords{ $moduleName } = { %hash };
			$zbsModuleRecords{ $moduleName }{FILENAME} =   ( $file );

			# EXTRACT the header files that comprise this module
			foreach( @{$hash{REQUIRED_FILES}}, @{$hash{OPTIONAL_FILES}} ) {
				if( /\.(h|hpp)/ ) {
					$zbsModuleByHeader{ ($_) } = $moduleName;
				}
			}
		}
	}

	# At this point, zbsModuleRecords and zbsModuleByHeader are filled in,
	# now we need to figure out which modules are actually used.
	#
	# EXTRACT which files are actually used into the usedFiles hash
	#
	my %usedFiles;

	my @deps = ( 'zplatform.cpp' );
		# The zplatform got added here because apple needed the assert_fail
		# Might be nice to clean this up so only is required on Apple

	#
	# SEED @deps with the plugins
	#

	my $foundConsole = 0;
	foreach my $pluginName( @configPlugins ) {
		if( $pluginInterface{$pluginName} eq 'console' ) {
			$foundConsole = 1;
		}
		
		push @deps, "_$pluginName.cpp";
	}
	$configInterface = 'console';
	if( ! $foundConsole ) {
		# If we have a console app, then we don't add main
		push( @deps, "main.cpp" );
		$configInterface = 'gui';
	}

	map{ $usedFiles{$_}++ } @deps;
	foreach $file( @deps ) {
		my @thisFilesDirectDeps = zbsModuleScanDirectDepends( $zbsModuleRecords{$file}{FILENAME}, $verbose );
			# The second arg here is verbose or not

		foreach( @thisFilesDirectDeps ) {
			if( !$usedFiles{$_} ) {
				push @deps, $_;
				$usedFiles{$_}++;
			}
		}
	}
	@configUsedFiles = keys %usedFiles;

	#
	# EXTRACT the SDKs that are used
	#
	my %usedSDKs;
	foreach my $module( keys %usedFiles ) {
		foreach my $sdk( @{$zbsModuleRecords{$module}{SDK_DEPENDS}} ) {
			if( $verbose ) {
				print "SDK $sdk from $module\n";
			}
			$usedSDKs{$sdk}++;
		}
	}

	#
	# EXTRACT the subdirectory specs that should be copied
	#
	@configPluginDirSpec = ();
	foreach my $module( keys %usedFiles ) {
		my %dirSpec;
		foreach my $subdir( @{$zbsModuleRecords{$module}{DIRSPEC}} ) {
			print "DIRSPEC in $module is [$subdir]\n" if( $verbose );
			push( @configPluginDirSpec, "$module&$subdir" );
		}
	}
	
	#
	# Kintek HACKS: 
	#
	my $platformDesc = platformDescription();
	if( $configPlugins[0] eq 'kin' && scalar(@configPlugins)==1 ) {
		if( $platformDesc eq 'win32' ) {
			# TFB upgraded the glfw version used by all of zlab, but there is some issue on
			# some windows machines in which glfw-2.7.2 fails the glfwOpenWindow call in main.cpp.  Since 
			# we don't have a machine we are able to reproduce this on, we are going to build win32 versions
			# of KinTek with the old glfw library.  Note that other zlab apps on win32 will continue to
			# use 2.7.2, so hopefully we'll run into this on a machine we can debug on and solve this 
			# problem correctly.  TFB 10 June 2012
			# 5.21.15 - we removed this.
			# 6.23.15 - I am reinstating this for 32bit builds of kintek software only.
			delete $usedSDKs{'glfw-2.7.2'};
			$usedSDKs{'glfw'}++;
			print "\n  *** Using older glfw library on $platformDesc for 32bit KinTek application.\n";
		}
	}


	@configUsedSDKs = sort( keys %usedSDKs );
		# TFB added sort because I need clapack to get built before levmar.
		# This seems as good as not since previously the order was somehwat random.
		# The right way to do this is to maintain the order of the sdks as specified in
		# modules when usedSDKs is being populated, so that the user can control this.


	# DUMP used
	if( $verbose ) {
		print "*** configUsedFiles\n";
		print join ", ", @configUsedFiles;
		print "\n";
	}

	
}

sub zbsModuleReadRecord {
	my( $filename ) = @_;

	my %hash;
	my $text;
	open( F, $filename );
	while( <F> ) {
		if( /\@ZBS/ ) {
			my $line;
			while( $line = <F> ) {
				last if( $line =~ /^\s+/ );
				if( $line =~ m#^//\s+\*([A-Z0-9_]+)\s+(.*)# ) {
					# FOUND a key value
					my $one = $1;
					my $two = $2;
					$hash{$one} = [ split( /\s+/, $two ) ];
				}
				if( $line =~ m#^//\s+\+([A-Z0-9_]+)\s+{# ) {
					# FOUND a multi-line key value
					$key = $1;
					$text = '';
					while( $line = <F> ) {
						last if( $line =~ m#^//\s+}# );
						$line =~ m#^//\s*(.*)#;
						$text .= $1 . "\n";
					}
					$hash{$key} = $text;
				}
			}
			last;
		}
	}
	close( F );
	$hash{FILENAME} = ( $filename );

	return %hash;
}

sub extraDefines( $ ) {
	# this is used with ZBSIF inside of C++ source files to allow
	# optional dependencies based on the EXTRA_DEFINES macro; see
	# for example kineticbase.h
	
	my $arg = shift;
	
	
	print "Looking for $arg defined...\n" if $verbose;
	
	foreach my $pluginName( @configPlugins ) {
		print "  checking for plugin _$pluginName.cpp\n" if $verbose;
		
		foreach( @{$zbsModuleRecords{ "_$pluginName.cpp" }{EXTRA_DEFINES}} ) {
			print( "    found $_\n" ) if $verbose;
			if( $_ eq $arg ) {
				print "      Match!  Returning 1\n" if $verbose;
				return 1;
			}
		}
	}
	return 0;
}

sub configDefined( $ ) {
	# Analagous to the above, but for the @configDefines array that is populated
	# by any special config setups for named configs, and then also receives
	# the EXTRA_DEFINES based on the plugin(s)
	my $arg = shift;
	
	print "Looking for $arg defined in \@configDefines...\n" if $verbose;
	
	foreach my $configDefine( @configDefines ) {
		print( "  found $configDefine\n" ) if $verbose;
		if( $configDefine eq $arg )  {
			print( "    found $arg, returning 1\n" ) if $verbose;
			return 1;
		}
	}
	return 0;

}

sub zbsModuleScanDirectDepends {
	# Given a file figure out all the other files
	# that it depends on.  This is done by analyzing
	# its headers and any depends or require options.
	# This only finds the direct dependencies, it does
	# not recurse to find indirect ones.
	# Note, the zbsModuleAnalyzeFromSearchPath must have
	# been called already to setup the %zbsModuleRecords and %zbsModuleByHeader hashes

	my( $file, $verbose ) = @_;
	my $moduleName =   ( (fparse( $file ))[2] . (fparse( $file ))[3] );

	my @moduleDepends;

	#
	# SCAN the header includes for this file pulling in any modules which are required by that header
	#
	open( FILE, $file );
	while( <FILE> ) {
		if( /^\/\/\s*\@ZBSIF\s+(.*)/ ) {
			# A header include option has been found. Read the line and evaluate it, if true include the contents otherwise skip
			if( ! eval($1) ) {
				print "Skipping section because $1 evals to false\n" if $verbose;
				$skipping = 1;
			}
			else {
				print "Including section because $1 evals to true\n" if $verbose;

			}
		}
		elsif( /^\/\/\s*\@ZBSENDIF/ ) {
			$skipping = 0;
		}
		elsif( !$skipping && /^\s*#include [\"<](.*)[\">]/ ) {
			#if( $zbsModuleByHeader{ lc($1) } ) {
			 if( $zbsModuleByHeader{   ($1) } ) {
				# removed lowercase for linux compat TFB 26 Mar 2008
				# Found a module, include all of its required files
				if( $verbose ) {
					print "From $file with header $1, adding: @{$zbsModuleRecords{ $zbsModuleByHeader{ $1 } }{REQUIRED_FILES}}\n";
				}
				push @moduleDepends, @{$zbsModuleRecords{ $zbsModuleByHeader{ $1 } }{REQUIRED_FILES}};
			}
		}
	}
	close( FILE );

	#
	# ADD the explicit depends that are listed by the ZBS record
	#
	foreach( @{$zbsModuleRecords{ $moduleName }{MODULE_DEPENDS}} ) {
		if( $_ !~ /\./ ) {
			print STDERR "Warning: $file has a malformed dependency.  Should include extensions.\n";
		}
		if( $verbose ) {
			print "From $file explictly adding: $_\n";
		}
		#push @moduleDepends, lc($_);
		 push @moduleDepends,   ($_);
			# removed lowercase for linux compat TFB 26 Mar 2008
	}

	return uniquify( @moduleDepends );
}

####################################################################################################
#
# BUILD and PACKAGE
#
####################################################################################################

sub createMakeFileAndOptionallyBuild {
	my( $build ) = @_;

	# EXTRACT the used files into the globals @configUsedFiles and @configUsedSDKs
	analyzeUsedFiles();

	# CONVERT all modules to their full path names
	my @fullFilenames;
	map { push @fullFilenames, $zbsModuleRecords{$_}{FILENAME} } @configUsedFiles;


	# INCLUDE all of the manually requested libs
	my @win32debuglibs;
	my @win32releaselibs;
	my @linuxlibs;
	my @win32debugdefines;
	my @win32releasedefines;
	map{ push( @win32debuglibs  , @{$zbsModuleRecords{$_}{WIN32_LIBS_DEBUG}  } ) } @configUsedFiles;
	map{ push( @win32releaselibs, @{$zbsModuleRecords{$_}{WIN32_LIBS_RELEASE}} ) } @configUsedFiles;
	map{ push( @configDefines, @{$zbsModuleRecords{$_}{EXTRA_DEFINES}} ) } @configUsedFiles;

	# INCLUDE the SDKs that are used and put them into the include paths
	# TNB - The win32libs files are added to both release and debug configurations.
	my @sdkIncludes;
	foreach my $sdk( @configUsedSDKs ) {
		push @sdkIncludes, @{ $sdkHash{$sdk}{includes} };
		push @sdkIncludes, @{ $sdkHash{$sdk}{$platform . 'includes'} };
		push @win32debuglibs, @{ $sdkHash{$sdk}{win32debuglibs} }, @{ $sdkHash{$sdk}{win32libs} };
		push @win32releaselibs, @{ $sdkHash{$sdk}{win32releaselibs} }, @{ $sdkHash{$sdk}{win32libs} };
		push @linuxlibs, @{ $sdkHash{$sdk}{linuxlibs} };
		push @macosxlibs, @{ $sdkHash{$sdk}{macosxlibs} };
		push @win32debugdefines, @{ $sdkHash{$sdk}{win32debugdefines} };
		push @win32releasedefines, @{ $sdkHash{$sdk}{win32releasedefines} };
	}

	my @win32InterfaceLibs  = $configInterface eq 'gui' ? ("opengl32.lib", "glu32.lib") : ();
	my @linuxInterfaceLibs  = $configInterface eq 'gui' ? qw^-lGL -lGLU -lX11 -L/usr/X11R6/lib^ : ();
	my @macosxInterfaceLibs = $configInterface eq 'gui' ? () : ();
		# on macosx we don't explicity link the gl/x11 stuff for gui since we get this from the mac opengl Framework which is
		# installed on all macs, whereas the X11 stuff may not be.

	if( $configPackageName ) {
		print "Building configured package $configPackageName ...\n";
	}
	platform_createMakefile(
		name => $configPackageName ? $configPackageName : 'zlab',
		files => [ sort @fullFilenames ],
		includes => [ @sdkIncludes, $zbslibDir, $zlabDir, @configSearchPath, "/usr/include", "/usr/X11R6/include" ],
		win32debugdefines => [ qw^WIN32 _DEBUG _WINDOWS _MBCS^, @win32debugdefines, @configDefines, "SVN_REV=$svnRev" ],
		win32releasedefines => [ qw^WIN32 NDEBUG _WINDOWS _MBCS^, @win32releasedefines, @configDefines, "SVN_REV=$svnRev" ],
		win32debuglibs => [ (@win32InterfaceLibs, @win32debuglibs, qw^winmm.lib psapi.lib kernel32.lib user32.lib gdi32.lib advapi32.lib shell32.lib ole32.lib shlwapi.lib^) ],
		win32releaselibs => [ (@win32InterfaceLibs, @win32releaselibs, qw^winmm.lib psapi.lib kernel32.lib user32.lib gdi32.lib advapi32.lib shell32.lib ole32.lib shlwapi.lib^) ],
		win32debugexcludelibs => [ qw^msvcrt.lib msvcrtd.lib^ ],
		win32releaseexcludelibs => [ qw^msvcrt.lib msvcrtd.lib^ ],
		win32icon => $configIconWin32,
		macosxicon => $configIconMacosx,
		linuxdefines => [ @configDefines ],
		linuxlibs => [ @linuxlibs, @linuxInterfaceLibs ],
		macosxdefines => [ @configDefines ],
		macosxlibs => [ @macosxlibs, @macosxInterfaceLibs ],
		interface => $configInterface,
	);
	
	#
	# EMIT plugin paths to the .cfg file
	#
	$coreDir = "$buildDir/core";
	mkdir( $coreDir );
	my $optionsFileName = "$coreDir/options.cfg";
	print "Building options file $optionsFileName \n" if( $verbose ); 
	open( OPTIONS, ">$optionsFileName" );
	foreach( @configPlugins ) {
		my $pluginPath = "pluginPath_" . $_ . ' = "' . $configPluginPaths{"_$_"} . '"' . "\n";
		print "ADDING: " . $pluginPath . "\n" if( $verbose );
		print OPTIONS $pluginPath;
		# print plugin-specific options if defined
		if( defined &{'options_' . $_} ) {
			&{'options_' . $_}( OPTIONS );
		}

	}
	close OPTIONS;

	#
	# CLEAN
	#
	recursiveUnlink( 'Debug' );
	recursiveUnlink( 'Release' );
	recursiveUnlink( 'zlab.app' );  #osx
	my $ret = platform_runMakefile( win64name=>'zlab.vcxproj', win32name=>'zlab.vcproj', linuxname=>'Makefile', macosxname=>'Makefile', target=>'clean', win32config=>'Debug' );
	print "make clean debug FAILURE\n" if( !$ret );
	my $ret = platform_runMakefile( win64name=>'zlab.vcxproj', win32name=>'zlab.vcproj', linuxname=>'Makefile', macosxname=>'Makefile', target=>'clean', win32config=>'Release' );
	print "make clean release FAILURE\n" if( !$ret );

	#
	# BUILD
	#
	if( $build ) {
		print "Building...\n";

		$ret = platform_runMakefile( win64name=>'zlab.vcxproj', win32name => 'zlab.vcproj', linuxname => 'Makefile', macosxname => 'Makefile', win32config => 'Release' );
		print $ret ? "make release success\n" : "make FAILURE\n";
	}

	#
	# COPY the dlls
	#
	if( $platform eq 'win32' ) {
		mkdir( "$buildDir/Release" );
		mkdir( "$buildDir/Debug" );
		foreach( @configUsedSDKs ) {
			my @dlls = @{ $sdkHash{$_}{win32dlls} };
			foreach( @dlls ) {
				cp( $_, $buildDir );
				cp( $_, "$buildDir/Release" );
				cp( $_, "$buildDir/Debug" );
			}
		}
	}
	elsif( $platform eq 'macosx' ) {
	    # the make should have already created the crazy macosx bundle hierarchy.  Copy the dylibs inside it...
		foreach( @configUsedSDKs ) {
			my @macdlls = @{ $sdkHash{$_}{macosxdlls} };
			foreach( @macdlls ) {
				cp( $_, "$buildDir/zlab.app/Contents/MacOS/libs" );
			}
		}
	}
	
	return $ret;
	#return status of build, if we tried to build
}

sub createSignedDmg {
	my $dstDir = shift;
	my $basePackageName = shift;
	my $signature = shift;

	print "Creating DMG and code-signing for OSX...\n";
	
	my $packageName = $basePackageName;
	$packageName .= "_MacOSX.dmg";
	unlink( $packageName );

	#
	# codesign the actual app; that id/cert must exist on the machine for the KinTek Developer ID
	#
	my $codesignAppCmd = "find $dstDir -name '*.app' | xargs codesign --deep --force --sign $signature";
	`$codesignAppCmd`;


	# hdiutil will copy everything inside the dstDir, but we need the enclosing folder
	# as well to make installation easier via the app.  So put all the dstDir inside
	# yet another folder called "dmg"
	$dmgDir = "dmg";
	rmtree( $dmgDir );
	mkdir( $dmgDir );
	move( $dstDir, $dmgDir . "/" . $dstDir );

	#
	# put a link to the applications folder inside of the dmg, for user to drag the app to.
	#
	symlink( "/Applications", "$dmgDir/Applications" );

	#
	# and create the disk image.
	#
	my $compressCmd = "hdiutil create $packageName -volname '$basePackageName' -srcFolder $dmgDir -format UDRW";
	`$compressCmd`;

	#
	# mount the disk so that we can set various view options
	#
	my $cmd = "hdiutil attach -readwrite -noverify '$packageName' | egrep '^/dev/' | sed 1q | awk '{print \$1}'";
	my $device = `$cmd`;

	#
	# if there is a background image, copy it into place.  The following finds the FIRST
	# file named background.png in the package and uses it.
	#
	mkdir( "/Volumes/$basePackageName/.background" );
	my $backgroundName = "background144DPI.png";
	my $moveBackgroundCmd = "find $dmgDir/$dstDir -name '$backgroundName' -exec cp {} /Volumes/$basePackageName/.background \\; -quit";
	`$moveBackgroundCmd`;

	#
	# if we have a background, run some "apple script" to configure the styling of the folder
	# when the user mounts the diskimage and looks at it.
	# 
	my $script = <<OSASCRIPT;
tell application "Finder"
 tell disk "$basePackageName"
       open
       set current view of container window to icon view
       set toolbar visible of container window to false
       set statusbar visible of container window to false
       set the bounds of container window to {400, 80, 1000, 500}
       set viewOptions to the icon view options of container window
       set arrangement of viewOptions to not arranged
       set icon size of viewOptions to 100
       set background picture of viewOptions to file ".background:$backgroundName"
       set position of item "$dstDir" of container window to {150, 150}
       set position of item "Applications" of container window to {450, 150}
       close
       open
       update without registering applications
       delay 2
       close
       eject
 end tell
end tell
OSASCRIPT

	my $osaCmd = "osascript -e '$script'";
	`$osaCmd`;

	# In OSX 10.13(.1?) the detach starting failing, saying that the resource was busy.
	# So I added the close and eject in the osascript above, and then I don't need to
	# detach anymore.  But I'm getting some kind of strange nx_kernel_mount messages
	# that I think are the result of the eject, I'm not sure.  The output is ugly,
	# but it seems to work.  I had added the sleep(3) because I thought
	# it might allow the detach to work with just a "close" in the osascript, 
	# but it didn't.  tfb nov 10, 2017

	#sleep( 3 );


	#
	# Detach the mounted volume, and convert the dmg to a compressed image.
	#
	#my $detachCmd = "hdiutil detach $device"; 
	#`$detachCmd`;

	my $tmp = $basePackageName . ".tmp.dmg";
	move( "$packageName", $tmp );

	`hdiutil convert $tmp -format UDBZ -o $packageName`;
	`rm -f $tmp`;

	`rm -rf dmg`;
	`rm -rf zlab.app`;
	`rm nul`;
	`rm __svn__`;
	`rm a.out`;

	#
	# Now we also have to codesign the entire DMG, since other resources exist outside
	# of the .app itself.
	#
	my $codesignDmgCmd = "codesign --deep --force --sign $signature $packageName";
	`$codesignDmgCmd`;

	#
	# Finally, call it a success if the diskimage is there.  We could also
	# validate the signature, etc.
		#
	if (-s "$packageName") {
		printf "OSX diskimage created: $packageName ( $compressCmd )\n";
		push @packagesCreated, $packageName;
	}
	else {
		printf "OSX diskimage $packageName failed. ( $compressCmd )\n";
	}
}

sub packageZlab() {
	#
	# PACKAGE to config-specific location, or env-var specified, or default '/zlab'
	#	
	my $platformDesc = platformDescription();
	my $dstDir = $configPackageTo ? $configPackageTo : "./zlab_package_$platformDesc";

	#
	# CLEAR the dst folder
	#
	print "Packaging to $dstDir\n";
	recursiveUnlink( $dstDir );
	if( -d $dstDir ) {
		print "\n* PACKAGING ERROR: The destination folder $dstDir could not be removed!\n";
		print "  Ensure you aren't using this folder or its subfolders in any way, such\n";
		print "  as viewing them in Explorer, or running a program that lives within.\n\n";
		exit;
	}
	mkdir( $dstDir );
	
	$coreDir = "$dstDir/core";
	mkdir( $coreDir );

	#
	# COPY program files
	#
	if( $platform eq 'win32' ) {
		cp( "$buildDir/Release/zlab.exe", "$dstDir/zlab.exe" );
	}
	if( $platform eq 'macosx' ) {
		cpRecurse( "$buildDir/zlab.app", "$dstDir/zlab.app" );
	}
	if( $platform eq 'linux' ) {
		cp( "$buildDir/zlab", "$dstDir/zlab" );
	}	
	
	#
	# COPY the dlls, dynamic libs
	#
	foreach( @configUsedSDKs ) {
		my @dlls = @{ $sdkHash{$_}{$platform."dlls"} };
		foreach( @dlls ) {
			tr/\\/\//;
			/^.*\/(.*)/;
			if( $platform eq 'win32' ) {
				cp( $_, "$dstDir/$1" );
			}
			elsif( $platform eq 'macosx' ) {
				#cp( $_, "$dstdir/zlab.app/Contents/MacOS/libs/$1" );
				# these were already copied as part of the build process.
			}
			else {
				mkdir( "$dstDir/libs" );
				cp( $_, "$dstDir/libs/$1" );
			}
		}
	}

	#
	# COPY zui
	#
	if( $configInterface eq 'gui' ) {
		cp( "$zlabDir/main.zui", $coreDir );
	}

	#
	# COPY main python file
	#
	if( $configInterface eq 'gui' ) {
		cp( "$zlabDir/main.py", $coreDir );
	}

	#
	# COPY fonts
	#
	if( $configInterface eq 'gui' ) {
		my @glob = <$zlabDir/*.ttf>;
		foreach( @glob ) {
			cp( $_, $coreDir );
		}
	}

	#
	# COPY plugin stuff
	# @TODO: Need to exclude source files out of this or reorganize!
	#
	
	#
	# CREATE options.cfg - do this before the plugin-specific config below in case
	# the plugin wants to modify it.
	#
	if( $configInterface eq 'gui' ) {
		print "Generating options.cfg to $coreDir/options.cfg" if( $verbose );
		open( F, ">$coreDir/options.cfg" );
		print F "// This file is where you should put any variable changes you wish to make\n";
		print F "// To edit this, you might have to make it writable\n";
		print F "// by running \"attrib -r \\sg\\options.cfg\" on the command line\n";
		print F "// Place any custom variables here; for example:\n";
		print F "//Bfly_count = 100\n";
		print F "//Bfly_brightness = 20\n";
		print F "\n";
		print F "startupPlugin = $configPlugins[0]\n";
		print F "\n";

		foreach( @configPlugins ) {
			$pluginPathAssignment = "pluginPath_" . $_ . ' = "' . "./_$_" . '"' . "\n";
			print $pluginPathAssignment if( $verbose );
			print F $pluginPathAssignment;
			# print plugin-specific options if defined
			if( defined &{'options_' . $_} ) {
				&{'options_' . $_}( F );
			}

		}

		close( F );
	}

	# RUN configuration specific copy
	if( defined &{'config_' . $configName} ) {
		&{'config_' . $configName}( 0, $dstDir );
	}
	else {
		#$plugHomeDir = $coreDir;
		$plugHomeDir = "$dstDir";
		foreach $plugin( @configPlugins ) {
			print "Copying $plugin\n";
		
			# @TODO: don't make the subdirs if they are empty

			mkdir( $plugHomeDir );
			
			$plugDir = "$plugHomeDir/_$plugin";
			mkdir( $plugDir );

			# COPY the .zui for the plugin
			my @glob = <$zlabDir/../plug_public/_$plugin/*.zui>;
			foreach( @glob ) {
				cp( $_, $plugDir );
			}

			# COPY all subdirs for the plugin
			$pluginMainFile = "_" . $plugin . ".cpp";
			
			print "Copying DIRSPECs for $pluginMainFile\n" if( $verbose );
			foreach $spec( @configPluginDirSpec ) {
				my( $module, $dirspec ) = split( '&', $spec );
				if( $module eq $pluginMainFile ) {
					my( $volPart, $dirPart, $filePart ) = File::Spec->splitpath( $dirspec );
					print "mkdir $plugDir/$dirPart\n" if( $verbose );
					mkdir( "$plugDir/$dirPart" );
					print "copying $filePart\n" if( $verbose );
					my @glob = <$zlabDir/../plug_public/_$plugin/$dirspec>;
					foreach( @glob ) {
						$target = "$plugDir/$dirPart";
						#print "copy $_ to $target\n" if( $verbose );
						cp( $_, $target );
					}
				}
			}
		}
	}

	#
	# COMPRESS
	#

	# Package into a single compressed file for distribution.
	# We append OS/processor ids as necessary since these files
	# need to be individually recognizable as to platform.
	@packagesCreated = ();
	my $basePackageName = $configPackageName ? $configPackageName : "zlab";
	my $packageName = $basePackageName;
	if( $platform eq 'macosx' || $platform eq 'linux' ) {
		$packageName .= "_" . $platformDesc if !$packageName !~ /$platformDesc/;
		$packageName .= ".tar.gz";
		unlink( $packageName );
		my $compressCmd = "tar -pczf $packageName $dstDir 2> /dev/null";
		my( $volume, $directories, $file ) = File::Spec->splitpath( $dstDir );
		if( $directories ne "" && $file ne "" ) {
			$compressCmd = "tar -C $directories -pczf $packageName $file 2> /dev/null";
				# cause the tar file to only contain the leaf node of the path
		}
		`$compressCmd`;
		if (-s "$packageName") {
			printf "Distribution created: $packageName ( $compressCmd )\n";
			push @packagesCreated, $packageName;
		}
		else {
			printf "Create distribution $packageName failed. ( $compressCmd )\n";
		}
	}
	if( $platform eq 'macosx' && index($basePackageName,'KinTek') != -1 ) {
		# Because OSX 10.12 (Sierra) requires that we start code-signing the package
		# to avoid Gatekeeper path randomization (which prevents us from loading path-relative
		# files), we need to now package as a disk-image on OSX, and then code-sign 
		# the disk-image.  We also need to code-sign the app itself.  This is for KinTek
		# only, and we use the ID tht refs the KinTek Deverloper ID cert to sign with.
		my $signature = '8Y42SX3ZP3';
			# this refers to a certificate/key-pair that must exist on the developer
			# machine that builds this software for distribution.
		createSignedDmg( $dstDir, $basePackageName, $signature );

		# If we're creating a signed dmg, which consumes the build folder for itself,
		# then unpack the compressed version so it's available for automated testing etc.
		if( ! -d $dstDir ) {
			$uncompressCmd = "tar -xzf $packageName";
			`$uncompressCmd`;
		}
	}
	if( $platform eq 'win32' ) {
		my $packageName = $basePackageName;
		$packageName .= "_" . $platformDesc if $packageName !~ /$platformDesc/;
		$packageName .= ".zip";
		unlink( $packageName );
		my $compressCmd = "$zlabDir/tools/zip.exe -rq $packageName $dstDir"; 
		`$compressCmd`;
		if( -s "$packageName" ) {
			printf "Distribution created: $packageName ( $compressCmd )\n";
			push @packagesCreated, $packageName;
		}
		else {
			printf "Create distribution $packageName failed. ( $compressCmd )\n";
		}

	}
}


####################################################################################################
#
# UTILITY
#
####################################################################################################

sub svnRevision( $ ) {
	my ( $pathForVersion ) = @_;
	$pathForVersion = ".." if( $pathForVersion eq "" );
	my $str = `svn info $pathForVersion 2> __svn__`;
		# the assumption here is that we're running from zlabcore, so we want the
		# svn rev of the parent folder if nothing else specified
	$str =~ /Revision: (\d+)/;
	$rev = $1;
	if( $rev eq '' ) {
		# print "No svn revision found, assuming we're using git.  Using date for build-revision/ID.\n";
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$year -= 100;
		$mon  += 1;
		if( $mon < 10 ) {
			$mon = "0$mon";
		}
		if( $mday < 10 ) {
			$mday = "0$mday"
		}
		$rev = "$year$mon$mday";
	}
	return $rev;
}

sub checkForSvn() {
	my $result = `svn help 2> __svn__`;
	unlink( "__svn__" );
	if( $result =~ /usage: svn/ ) {
		return 1;
	}
	return 0;
}

sub determinePlatform {
	my $str = `sw_vers 2> nul`;
	if( $str =~ /Mac OS X/i ) {
		unlink "nul";
		return "macosx";
	}

	$str = `ver 2> nul`;
	if( $str =~ /microsoft windows/i ) {
		return "win32";
	}

	$str = `uname 2> nul`;
	if( $str =~ /linux/i ) {
		unlink "nul";
		return "linux";
	}
}

sub platformBuild64Bit {
	# will zlab be build as 64bit on this platform?
	my $build64bit = 0;
	
	my $platform = determinePlatform();
	if( $platform eq 'win32' ) {
		$build64bit = 0;
			# almost always build 32bit on windows
		if( $configName eq 'kin_dev' || $configName eq 'kin_pro' || $configName eq 'kin_pro_py' ) {
			$build64bit = 1;
				# experimental, starting to ship to users june 2015 (kintek)
		}
	}

	if( $platform eq 'linux' ) {
		$build64bit = 1;
			# always build 64bit on linux
	}

	if( $platform eq 'macosx' ) {
		# depends on OS version: build64bit for 10.5 and greater
		$build64bit = 0;
		my $str = `sw_vers 2> nul`;
		$str =~ /ProductVersion:\s*(\d+)\.(\d+)/;
		if( $1 == "10" && $2 >= 5 ) {
			$build64bit = 1;
		}
	}
	
	return $build64bit;
}

sub platformDescription {
	my $s;

	if( $platform eq 'win32' ) {
		$s = platformBuild64Bit() ? "Win64" : "Win32";
	}
	elsif( $platform eq 'linux' ) {
		# @TODO Linux may get much more compilcated if we do distribution specific
		$s = "Linux";
	}
	elsif( $platform eq 'macosx' ) {
		$s = "MacOSX";
	}

	return $s;
}

sub testCompiler {
	my( $platform ) = @_;

	if( $platform eq 'win32' ) {
		# win32 is our generic name for the windows platform, although maybe this should change.
		# Normally we want to build 32bit versions of stuff with vs2008 since that's what we've
		# done for the last 5+ years, but I want to allow 64bit builds if desired using vs2013.
		# So there is a function platformBuild64Bit() which tells us if we should build with
		# 64bit.  Right now that is determined based on the plugin configuration, but we could
		# make it menu-selectable etc.  (tfb 2 june 2015)

		my $build64bit = platformBuild64Bit();

		my @vs2013Amd64Dirs = ( "$ENV{ProgramFiles}/microsoft visual studio 12.0/vc/bin/amd64", "$ENV{ProgramFiles} (x86)/microsoft visual studio 12.0/vc/bin/amd64" );
		if( $build64bit && ! findDirectory( @vs2013Amd64Dirs )  ) {
			return "Configuration calls for 64bit build but amd64 tools not found.  Is Visual Studio 2013 installed?\n";
		}

		my @vs2013x86Dirs = ( "$ENV{ProgramFiles}/microsoft visual studio 12.0/vc/bin", "$ENV{ProgramFiles} (x86)/microsoft visual studio 12.0/vc/bin" );
		my @vs2008Dirs = ( "$ENV{ProgramFiles}/Microsoft Visual Studio 9.0/VC/bin", "$ENV{ProgramFiles} (x86)/Microsoft Visual Studio 9.0/VC/bin" );		
		
		#
		# If we're building 64bit, look for vs2013 first.  Else look for vs2008 first.
		# Note that we've already dealt with the error condition of wanting to build x64 but not finding 64bit-compilers.
		#
		my @dirs = ();
		push @dirs, @vs2013Amd64Dirs if $build64bit;
		push @dirs, ( "$ENV{ProgramFiles}/Microsoft Visual Studio 9.0/VC/bin", "$ENV{ProgramFiles} (x86)/Microsoft Visual Studio 9.0/VC/bin" );
		push @dirs, @vs2013x86Dirs;
		#my @vc98dirs = ( "/dev/vc98/bin", "$ENV{ProgramFiles}/visual studio/vc98/bin", "./dev/vc98/bin", "../dev/vc98/bin", "../../dev/vc98/bin", "$ENV{ProgramFiles}/Microsoft Visual Studio/VC98/Bin" );
			# I think we can ditch these by now?

		$devDir = findDirectory( @dirs );		
		$devDir || return "Unable to find the windows compiler.";

		if( $devDir =~ /12\.0/ ) {
			# We're going to build with vs2013, but we still may be trying to build 32bit software.
			# This is new as of Feb 2017 -- kinexp no longer builds 32bit, but the stopflow software
			# relies on lots of 3rd party DLLs etc and I don't want to go messing with all of that stuff
			# and prefer to continue to build it 32bit.  And I don't want to have to install vs2008.
			my @sdkDirs = ( "$ENV{ProgramFiles}/Windows Kits/8.1", "$ENV{ProgramFiles} (x86)/Windows Kits/8.1" );
			$winSdkDir = findDirectory( @sdkDirs );
			if( $build64bit ) {
				$ENV{PATH} = "$devDir;$devDir/../../vcpackages;$devDir/../../../common7/ide;$winSdkDir/bin/x64;/Program Files (x86)/MSBuild/12.0/bin/amd64;" . $userPath;
			}
			else {
				$ENV{PATH} = "$devDir;$devDir/../../vcpackages;$devDir/../../../common7/ide;$winSdkDir/bin;/Program Files (x86)/MSBuild/12.0/bin;" . $userPath;				
			}
		}
		else {
			#
			# WARNING: I have messed with the $ENV path below, and it is not working like I expect it to.  If I add explicit paths to where I know cl.exe is,
			# it stil can't find the compiler, but if I include the $userPath, which contains the same strings, it does. TFB june 2015
			#
			my @sdkDirs = ( "$ENV{ProgramFiles}/Microsoft SDKs/Windows/v6.0a", "$ENV{ProgramFiles} (x86)/Microsoft SDKs/Windows/v6.0a" );
			$winSdkDir = findDirectory( @sdkDirs );
			$ENV{PATH} = "$devDir;$devDir/../vcpackages;$devDir/../../common7/ide;$winSdkDir/bin;$winSdkDir/bin;" . $userPath;
		}

		# TEST that the compiler is working and right version
		$ver = `cl 2> __cl__`;
		open( FILE, "__cl__" );
		$result = <FILE>;
		close( FILE );
		if( $result =~ /Compiler Version (1[23458])/i ) {
			$devVersion = $1;
		}
		else {
			return "Unable to run cl or wrong version of MSDEV 6.0, vs2008, or vs2013 (devVersion=$devVersion), ENV{PATH} is $ENV{'PATH'}";
		}
		unlink( "__cl__" );

		# TEST that the linker is working and right version
		$result = `link`;
		if( $build64bit && $result =~ /Linker Version ([xyz]|12)/ ) {
			# ok - have 64bit compiler
		}
		elsif( !$build64bit && $result =~ /Linker Version ([6789]|12)/ ) {
			# ok - can build 32bit apps with these
		}
		else {
			return "Unable to run link or wrong version of MSDEV 6.0, vs2008, or vs2013";
		}

		if( $devVersion == 18 ) {
			# vs2013
			if( $build64bit ) {
				$ENV{INCLUDE} = "$devDir/../../include;$winSdkDir/include/shared;$winSdkDir/include/um";
				$ENV{LIB} = "$devDir/../../LIB/amd64;$winSdkDir/lib/winv6.3/um/x64";
			}
			else {
				$ENV{INCLUDE} = "$devDir/../include;$winSdkDir/include/shared;$winSdkDir/include/um";
				$ENV{LIB} = "$devDir/../LIB;$winSdkDir/lib/winv6.3/um/x86";				
			}
		}
		else {
			$ENV{INCLUDE} = "$devDir/../include;$winSdkDir/include";
			$ENV{LIB} = "$devDir/../lib;$winSdkDir/lib";
		}

		return "OK";
	}
	elsif( $platform eq 'linux' ) {
		$ver = `g++ --version`;
		# @TODO: Setup $devVersion here 
		if( $ver !~ /g\+\+/ ) {
			return "Unable to run g++";
		}
		return "OK";
	}
	elsif( $platform eq 'macosx'){
		$ver = `g++ --version`;
		# @TODO: Setup $devVersion here 
		if( $ver !~ /g\+\+/ && $ver !~ /LLVM/ ) {
			return "Unable to run g++";
		}
		# Test for Objective-C -- the native filedialogs require this.  If you're not using them, you may
		# not need Objective-C, but it is there by default on all OSX systems with dev tools installed.
		open F, ">t.m" or die "Can't open t.m to test Objective-C compiler!";
		print F "int main() { return 0; }";
		close F;
		my $result = `g++ t.m 2>__stderr__`;
		if( $? != 0 ) {
				# Objective-C not installed: usually because user installed a newer gnu toolchain that does not
				# include Objective-C -- so try adding /usr/bin to PATH where the Apple-provided g++ lives.
				$result = `/usr/bin/g++ t.m 2>__stderr__`;
				if( $? != 0 ) {
						return "Unable to run Objective-C compiler";
				}
				print "Adding /usr/bin to front of path during build for g++ that supports Objective-C ...\n";
				$ENV{PATH}="/usr/bin:$ENV{PATH}";
		}
		unlink "__stderr__";
		unlink "t.m";
		return "OK";
	}
	return "Unable to find compiler";
}

sub fparse {
	# Parses a path and returns a list
	# [0] = drive ( c: ) or computer ( //computer )
	# [1] = path with final /
	# [2] = file
	# [3] = extension

	local( $f, $expand ) = @_;
	local( @p );

	local( $translate ) = 0;
	if( $f =~ m/\\/ ) {
		$f =~ tr#\\#/#;
		$translate = 1;
	}
	$p[2] = $f;
	if( $f =~ m#^([A-Za-z]:)?(//[^/]+)?(.*/)(.*)# ) {
		$p[0] = $1 ? $1 : $2;
		$p[1] = $3;
		$p[2] = $4;
	}
	if( $p[2] =~ /(.*)(\..*)/ ) {
		$p[2] = $1;
		$p[3] = $2;
	}

	if( $expand && (!$p[0] || !$p[1]) ) {
		# If drive or directory are not included,
		# Add the current drive and directory
		# TODO: Make this portable
		$curDir = './';
		if( $curDir !~ m#(/|\\)$# ) {
			$curDir .= '/';
		}
		if( $curDir =~ m/\\/ ) {
			$curDir =~ tr#\\#/#;
			$translate = 1;
		}

		$curDir =~ m#^([A-Za-z]:)?(//[^/]+)?(.*/)(.*)#;
		unless( $p[0] ) {
			$p[0] = $1 ? $1 : $2;
		}
		unless( $p[1] ) {
			$p[1] = $3;
		}
	}

	$p[0] =~ tr#/#\\# if $translate;
	$p[1] =~ tr#/#\\# if $translate;

	return @p;
}

sub translateSlashes {
	my( $str ) = @_;
	if( $platform eq 'win32' ) {
		$str =~ tr^/^\\^;
	}
	else {
		$str =~ tr^/^\\^;
	}
	return $str;
}

sub executeCmd {
	my( $cmd ) = @_;
	my( $dieOnError ) = @_;
	my $cwd = getcwd();
	if( $verbose ) {
		print "Executing (in $cwd): '$cmd'\n";
		print "ENV{path} is: $ENV{path}\n";
	}

	#On some mac builds we found that having CPPFLAGS and LDFLAGS set redirects
	#links and compiles to the wrong place so we push and reset here
	#print "** $ENV{path}\n";

	my $oldCPPFLAGS = $ENV{CPPFLAGS};
	my $oldLDFLAGS = $ENV{LDFLAGS};
	$ENV{CPPFLAGS}='';
	$ENV{LDFLAGS}='';	
	my $result = `$cmd 2> __stderr__`;
	$ENV{CPPFLAGS}=$oldCPPFLAGS;
	$ENV{LDFLAGS}=$oldLDFLAGS;
	if( $? == 0 && $verbose ) {
		print "STDOUT :\n$result\n\n";
		print "STDERR :\n";
		open( FILE, "__stderr__" );
		while( <FILE> ) { print; }
		close( FILE );
	}
 	if( $? != 0 ) {
		print "\n";
		print "========================= ERROR =========================\n";
		print "ERROR when executing '$cmd':\n";
		print "--------------------- TRACE FROM TOOL -------------------\n";
		print $result;
		print "stderr:\n";
		open( FILE, "__stderr__" );
		while( <FILE> ) { print; }
		close( FILE );
		print "-------------------- END TRACE FROM TOOL ----------------\n\n";
		unlink( "__stderr__" );
		if( $dieOnError ) {
			die;
		}
		return 0;
	}
	unlink( "__stderr__" );
	return 1;
}

sub pushCwd {
	my( $newDir ) = @_;
	use Cwd;
	$dir = cwd;
	push @cwdStack, $dir;
	$res = chdir( $newDir );
}

sub popCwd {
	my $dir = pop @cwdStack;
	chdir $dir;
}

sub findDirectory {
	my @list = @_;
	foreach( @list ) {
		if( -d $_ ) {
			if( ! File::Spec->file_name_is_absolute($_) ) {
				return File::Spec->rel2abs($_);
			}
			return $_;
		}
	}
}

sub isFileHidden {
	my $attrib;
	my( $filename ) = @_;
	if( ! $platform ) {
		$platform = determinePlatform();
	}
	if( $platform eq 'win32' ) {
		require Win32::File;
		Win32::File::GetAttributes( $filename, $attrib );
		return ($attrib & 2) ? 1 : 0;
	}
	else {
		return ($filename =~ /^\./) ? 1 : 0;
	}
}

sub recursiveUnlink {
	my $dir = shift;
	opendir DIR, $dir or return;
	my @contents = map "$dir/$_", sort grep !/^\.\.?$/, readdir DIR;
	closedir DIR;
	foreach( @contents ) {
		if( -f || -l ) {
			unlink( $_ );
		}
		elsif( -d ) {
			&recursiveUnlink($_);
		}
	}
	rmdir $dir;
}

sub _recurseDir {
	my $dir = shift;
	push @_recursedirs, $dir;
	opendir DIR, $dir or return;
	my @contents = map "$dir/$_", sort grep !/^\.\.?$/, readdir DIR;
	closedir DIR;
	map { &_recurseDir($_) if -d && !isFileHidden($_); } @contents;
}

sub recurseDir {
	undef @_recursedirs;
	_recurseDir( $_[0] );
	return @_recursedirs;
}

sub cp {
	use File::Copy;
	my( $src, $dst ) = @_;
	if( $dst eq '' ) {
		$dswt = '.';
	}
	if( -d $dst ) {
		tr/\\/\//;
		$src =~ /^.*\/(.*)/;
		$dst .= "/$1";
	}
	if( -f $src ) {
		my $mode = (stat($src))[2];
		my $dateSrc = (stat($src))[9];
		my $dateDst = (stat($dst))[9];
		copy( $src, $dst );
		chmod( $mode, $dst );
	}
}

sub fullMkdir {
	my( $dir ) = @_;
	my @dirParts = split( /\//, $dir );
	$dir = "";
	foreach( @dirParts ) {
		$dir .= "$_/";
		mkdir( $dir );
	}
}

sub cpRecurse {
	my( $src, $dst ) = @_;

	#normalize slashes
	$src =~ s/\\/\//g;
	$dst =~ s/\\/\//g;

	my @dirs = recurseDir( $src );
	foreach $dir( @dirs ) {
		my $dstDir = $dir;
		$dstDir =~ s/^$src/$dst/;
		fullMkdir( $dstDir );

		opendir DIR, $dir;
		my @glob = map "$dir/$_", sort grep !/^\.\.?$/, readdir DIR;
		closedir DIR;

		foreach( @glob ) {
			my $s = $_;
			my $d = $_;
			if( ! -d $s ) {
				$d =~ s/^$src/$dst/;
				if( $verbose ) {
					print "Copy $s to $d\n";
				}
				cp( $s, $d );
			}
		}
	}
}

sub readAllLines {
	my( $filename ) = @_;
	my @lines;
	open( FILE, $filename ) || die( "Unable to open $filename\n" );
	while( <FILE> ) {
		chomp;
		push @lines, $_;
	}
	close( FILE );
	return @lines;
}

sub uniquify {
	my @list = @_;
	my %uniq;
	foreach my $a( @list ) {
		$uniq{$a}++;
	}
	my @k = keys %uniq;
	@k = sort @k;
	return @k;
}

####################################################################################################
#
# USER INTERFACE
#
####################################################################################################

sub menu {
	my @menu = @_;
	my @lines;
	my @routines;
	my $title;

	for( my $i = 0; $i <= $#menu/2; $i++ ) {
		if( $menu[$i] eq '_title' ) {
			$title = $menu[$i*2+1];
		}
		else {
			push @lines, $menu[$i*2];
			push @routines, $menu[$i*2+1];
		}
	}

	if( $title ) {
		print "$title\n"
	}

	my $l = 0;
	foreach( @lines ) {
		printf "  %-2d) $_\n", $l;
		$l++;
	}

	print "\n  Enter choice: ";

	my $which = <STDIN>;
	if( $which >= 0 && $which <= scalar @lines ) {
		$routines[$which]->();
	}
}

sub radioMenu {
	my %list = @_;

	my @sorted = sort keys %list;
	my @keyFromNum;

	while( 1 ) {
		printf( "   0) Exit Menu\n" );
		my $l = 1;
		foreach( @sorted ) {
			printf( "  %2d) (%s) %s\n", $l, $list{$_} ? "*" : " ", $_ );
			push @keyFromNum, $_;
			$l++;
		}
		my $which = <STDIN>;
		if( $which == 0 ) {
			last;
		}
		if( $which >= 1 && $which < $l ) {
			foreach( @sorted ) {
				$list{$_} = 0;
			}
			$list{ $keyFromNum[$which-1] } = !$list{ $keyFromNum[$which-1] };
		}
	}
	return %list;
}

sub checkMenu {
	my %list = @_;

	my @sorted = sort keys %list;
	my @keyFromNum;

	while( 1 ) {
		printf( "   0) Exit Menu\n" );
		my $l = 1;
		foreach( @sorted ) {
			printf( "  %2d) (%s) %s\n", $l, $list{$_} ? "+" : " ", $_ );
			push @keyFromNum, $_;
			$l++;
		}
		my $which = <STDIN>;
		if( $which == 0 ) {
			last;
		}
		if( $which >= 1 && $which < $l ) {
			$list{ $keyFromNum[$which-1] } = !$list{ $keyFromNum[$which-1] };
		}
		cls();
	}
	return %list;
}

sub cls() {
#	if( $verbose ) {
		print "\n\n\n";
		return;
#	}
	for( $i=0; $i<200; $i++ ) {
		print "\n";
	}
}

sub wrapPrint {
	my $str = $_[0];
	$str =~ s/^\s+//g;
	$str =~ s/\s+/ /g;
	$str =~ s/\^n\s*/\n/g;
	$str =~ s/\^t\s*/\t/g;
	print $str;
}

####################################################################################################
#
# CROSS PLATFORM MAKEFILE CONSTRUCTION
#
####################################################################################################

sub platform_compile {
	return &{$platform . "_compile"};
}

sub platform_link {
	return &{$platform . "_link"};
}

sub platform_createMakefile {
	return &{$platform . "_createMakefile"};
}

sub platform_runMakefile {
	return &{$platform . "_runMakefile"};
}

sub linux_compile {
	my %options = @_;

	my @includes = @{$options{includes}};
	push @includes, @{$options{linuxincludes}};
	my $file = $options{file} || die "No input file specified to linux_compile";
	my $outfile = $options{outfile} || die "No output file specified to linux_compile";
	my @defines = @{$options{linuxdefines}};

	map{ tr^\\^/^ } @includes;
	$file =~ tr^\\^/^;
	$outfile =~ tr^\\^/^;

	map{ $_ = "-I\"$_\" " } @includes;
	$file = "\"$file\"";
	$outfile = "\"$outfile\"";
	map{ $_ = "-D$_" } @defines;

	my $debug = $options{debugsymbols} ? '-g' : '';

	return executeCmd( "g++ -c -fpermissive -Wno-non-template-friend @defines @includes $file -o $outfile" );
}

sub linux_link {
	my %options = @_;

	my @libs = @{$options{linuxlibs}};
	my @files = @{$options{files}};
	my $outfile = $options{outfile};
	my @defines = @{$options{linuxdefines}};

	die "No input files specified to linux_link" if scalar @files == 0;
	die "No output file specified to linux_link" if $outfile eq '';

	map{ tr^\\^/^ } @libs;
	map{ tr^\\^/^ } @files;
	$outfile =~ tr^\\^/^;

	map{ $_ = "\"$_\" " if substr( $_, 0, 1 ) ne '-' } @libs;
	map{ $_ = "\"$_\" " if substr( $_, 0, 1 ) ne '-' } @files;
	$outfile = "\"$outfile\"";
	map{ $_ = "-D$_" } @defines;

	my $ret = executeCmd( "libtool --mode=link g++ @defines @libs @files -o $outfile" );
	if( $outfile =~ /\"(.*)\.exe\"/ ) {
		# libtool refuses to create a exe file, it must be renamed if that's what you ask for
		rename( $1, "$1.exe" );
	}
	return $ret;
}

sub macosx_compile {
	my %options = @_;

	my @includes = @{$options{includes}};
	push @includes, @{$options{macosxincludes}};
	my $file = $options{file} || die "No input file specified to macosx_compile";
	my $outfile = $options{outfile} || die "No output file specified to macosx_compile";

	map{ tr^\\^/^ } @includes;
	$file =~ tr^\\^/^;
	$outfile =~ tr^\\^/^;

	map{ $_ = "-I\"$_\" " } @includes;
	$file = "\"$file\"";
	$outfile = "\"$outfile\"";

	my $debug = $options{debugsymbols} ? '-g' : '';

	return executeCmd( "g++ -c -fpermissive -Wno-write-strings -mmacosx-version-min=10.5 @includes $file -o $outfile" );
}

sub macosx_link {
	my %options = @_;

	my @libs = @{$options{macosxlibs}};
	my @files = @{$options{files}};
	my $outfile = $options{outfile};
	my $extralink = $options{macosxextralink};
	my $libtoolflags = $options{libtoolflags};

	die "No input files specified to macosx_link" if scalar @files == 0;
	die "No output file specified to macosx_link" if $outfile eq '';

	map{ tr^\\^/^ } @libs;
	map{ tr^\\^/^ } @files;
	$outfile =~ tr^\\^/^;

	map{ $_ = "\"$_\" " } @libs;
	map{ $_ = "\"$_\" " } @files;
	$outfile = "\"$outfile\"";

	my $ret = executeCmd( "glibtool $libtoolflags --mode=link g++ -mmacosx-version-min=10.5 @libs @files -o $outfile $extralink" );
	if( $outfile =~ /\"(.*)\.exe\"/ ) {
		# libtool refuses to create a exe file, it must be renamed if that's what you ask for
		rename( $1, "$1.exe" );
	}
	return $ret;
}

sub win32_compile {
	my %options = @_;

	my @includes = @{$options{includes}};
	push @includes, @{$options{win32includes}};
	my $file = $options{file} || die "No input file specified to win32_compile";
	my $outfile = $options{outfile} || die "No output file specified to win32_compile";
	my @defines = @{$options{win32defines}};

	map{ tr^/^\\^ } @includes;
	$file =~ tr^/^\\^;
	$outfile =~ tr^/^\\^;

	map{ $_ = "-I\"$_\" " } @includes;
	$file = "\"$file\"";
	$outfile = "\"$outfile\"";
	map{ $_ = "/D$_" } @defines;

	my $debug = '';
	if( $options{debugsymbols} ) {
		# SET the filename for the debug data file to be in same path as the output
		$outfile =~ m^(.*)\.obj^;
		$debug = "/Zi /Fd$1.pdb\"";
	}
	return executeCmd( "cl /c /nologo $debug @defines @includes /Fo$outfile $file" );
}

sub win32_link {
	my %options = @_;

	my @libs = @{$options{win32libs}};
	my @files = @{$options{files}};
	my @excludelibs = @{$options{win32excludelibs}};
	my $outfile = $options{outfile};

	die "No input files specified to win32_link" if scalar @files == 0;
	die "No output file specified to win32_link" if $outfile eq '';

	map{ tr^/^\\^ } @libs;
	map{ tr^/^\\^ } @files;
	map{ tr^/^\\^ } @excludelibs;
	$outfile =~ tr^/^\\^;

	map{ $_ = "\"$_\" " } @libs;
	map{ $_ = "\"$_\" " } @files;
	map{ $_ = "/nodefaultlib:\"$_\" " } @excludelibs;
	$outfile = "\"$outfile\"";

	my $debug = $options{debugsymbols} ? '/debug' : '';
	my $flags = $ENV{CL_FLAGS};
		# see testCompiler() where we setup 32 vs 64bit environment based on plugin
		# and available compilers on windows.

	return executeCmd( "link /nologo $flags $debug @libs @files @excludelibs /out:$outfile" );
}

sub win32_createMakefile {
	if( $devVersion >= 18 ) {
		# At present this only gets selected for doing 64bit builds on windows,
		# although it probably makes sense to convert our "standard" build tool
		# to vs2013 since it is modern and freely availabe.
		win32_createMakefile_VC120(@_);
	}
	elsif( $devVersion >= 15 ) {
		win32_createMakefile_VC90(@_);
	}
	elsif( $devVersion == 12 ) {
		win32_createMakefile_VC60(@_)
	}
	else {
		die "Unknown version to build";
	}
}

sub win32_createMakefile_VC60 {
	my %hash = @_;

	my @files = @{ $hash{files} };

	# CHECK for icon
	# If there's an icon file then we have to generate a resource.rc file and include it
	if( $hash{win32icon} ) {
		open( RESOURCE, ">resource.rc" );
		print RESOURCE "101 ICON DISCARDABLE \"_kin/kin.ico\"";
		close RESOURCE;
		push( @files, "resource.rc" );
	}

	# my $name = $hash{name};
	# tfb: hash{name} refers to the program name, but we still want the .dsp to always be
	# named zlab.dsp for convenience...
	my $name = "zlab";

	my $includes;

	map{ $_ =~ tr#/#\\#; $includes .= " /I " . "\"$_\"" } uniquify( @{$hash{includes}} );
	my $debLibs;
	my $relLibs;
	my $debExLibs;
	my $relExLibs;
	my $debDefines;
	my $relDefines;
	map{ $_ =~ tr#/#\\#; $debDefines .= " /D " . "$_" } uniquify( @{ $hash{win32debugdefines} } );
	map{ $_ =~ tr#/#\\#; $relDefines .= " /D " . "$_" } uniquify( @{ $hash{win32releasedefines} } );
	map{ $_ =~ tr#/#\\#; } uniquify @files;


	map{ $_ =~ tr#/#\\#; $debLibs .= " $_ " } uniquify( (@{ $hash{win32debuglibs} }) );
	map{ $_ =~ tr#/#\\#; $relLibs .= " $_ " } uniquify( (@{ $hash{win32releaselibs} }) );
	map{ $_ =~ tr#/#\\#; $debExLibs .= " /nodefaultlib:" . "\"$_\"" } uniquify( @{ $hash{win32debugexcludelibs} } );
	map{ $_ =~ tr#/#\\#; $relExLibs .= " /nodefaultlib:" . "\"$_\"" } uniquify( @{ $hash{win32releaseexcludelibs} } );
	my $subsystem = $hash{interface} eq 'console' ? '/subsystem:console' : '/subsystem:windows';

	#
	# The following are the options that are being set:
	#
	# DEBUG:
	# /nologo /MTd /W3 /Gm /GX /ZI /Od /YX /FD /GZ /c 
	# /MTd = link with libcmtd = c multi-threaded debug (this means that it staticly links as opposed to using msvcrtd.dll)
	# /W3 = warning level 3
	# /Gm = enable minimal rebuild
	# /GX = enable exception handling
	# /ZI = enable edit and continue debug info
	# /Od = disable optimizations
	# /YX = automatic use of pre compiled headers
	# /FD = ensures that the idb file has sufficient memory (see microsoft msdn docs!)
	# /GZ = enable runtime debug checks
	#
	# RELEASE:
	# /nologo /MT /W3 /GX /Zi /O2 /FR /YX /FD /c
	# /MT = link with libcmt = c multi-threaded non debug (this means that it staticly links as opposed to using msvcrtd.dll)
	# /W3 = warning level 3
	# /GX = enable exception handling
	# /Zi = enable debugging info
	# /O2 = maximize speed
	# /FR = name extended fbr file
	# /YX = automatic pre compiled header
	# /FD = ensures that the idb file has sufficient memory (see microsoft msdn docs!)
	#

	open( DSPFILE, ">$name.dsp" );

	print DSPFILE "# Microsoft Developer Studio Project File - Name=\"$name\" - Package Owner=<4>\n";
	print DSPFILE "# Microsoft Developer Studio Generated Build File, Format Version 6.00\n";
	print DSPFILE "# ** DO NOT EDIT **\n";
	print DSPFILE "\n";
	print DSPFILE "# TARGTYPE \"Win32 (x86) Application\" 0x0101\n";
	print DSPFILE "\n";
	print DSPFILE "CFG=$name - Win32 Debug\n";
	print DSPFILE "!MESSAGE This is not a valid makefile. To build this project using NMAKE,\n";
	print DSPFILE "!MESSAGE use the Export Makefile command and run\n";
	print DSPFILE "!MESSAGE \n";
	print DSPFILE "!MESSAGE NMAKE /f \"$name.mak\".\n";
	print DSPFILE "!MESSAGE \n";
	print DSPFILE "!MESSAGE You can specify a configuration when running NMAKE\n";
	print DSPFILE "!MESSAGE by defining the macro CFG on the command line. For example:\n";
	print DSPFILE "!MESSAGE \n";
	print DSPFILE "!MESSAGE NMAKE /f \"$name.mak\" CFG=\"$name - Win32 Debug\"\n";
	print DSPFILE "!MESSAGE \n";
	print DSPFILE "!MESSAGE Possible choices for configuration are:\n";
	print DSPFILE "!MESSAGE \n";
	print DSPFILE "!MESSAGE \"$name - Win32 Release\" (based on \"Win32 (x86) Application\")\n";
	print DSPFILE "!MESSAGE \"$name - Win32 Debug\" (based on \"Win32 (x86) Application\")\n";
	print DSPFILE "!MESSAGE \n";
	print DSPFILE "\n";
	print DSPFILE "# Begin Project\n";
		print DSPFILE "# PROP AllowPerConfigDependencies 0\n";
		print DSPFILE "# PROP Scc_ProjName \"\"\n";
		print DSPFILE "# PROP Scc_LocalPath \"\"\n";
		print DSPFILE "CPP=cl.exe\n";
		print DSPFILE "MTL=midl.exe\n";
		print DSPFILE "RSC=rc.exe\n";
		print DSPFILE "BSC32=bscmake.exe\n";
		print DSPFILE "LINK32=link.exe\n";
		print DSPFILE "\n";
		print DSPFILE "!IF  \"\$(CFG)\" == \"$name - Win32 Release\"\n";
		print DSPFILE "\n";
		print DSPFILE "# PROP BASE Use_MFC 0\n";
		print DSPFILE "# PROP BASE Use_Debug_Libraries 0\n";
		print DSPFILE "# PROP BASE Output_Dir \"Release\"\n";
		print DSPFILE "# PROP BASE Intermediate_Dir \"Release\"\n";
		print DSPFILE "# PROP BASE Target_Dir \"\"\n";
		print DSPFILE "# PROP Use_MFC 0\n";
		print DSPFILE "# PROP Use_Debug_Libraries 0\n";
		print DSPFILE "# PROP Output_Dir \"Release\"\n";
		print DSPFILE "# PROP Intermediate_Dir \"Release\"\n";
		print DSPFILE "# PROP Ignore_Export_Lib 0\n";
		print DSPFILE "# PROP Target_Dir \"\"\n";
		print DSPFILE "# ADD CPP /nologo /MT /W3 /GX /Zi /O2 /FR /YX /FD /c $includes $relDefines\n";
		print DSPFILE "# ADD LINK32 $relLibs $relExLibs /nologo $subsystem /debug /machine:I386 /incremental:yes\n";
		print DSPFILE "\n";
		print DSPFILE "# ADD MTL /nologo /D \"NDEBUG\" /mktyplib203 /win32\n";
		print DSPFILE "# ADD RSC /l 0x409 /d \"NDEBUG\"\n";
		print DSPFILE "# ADD BSC32 /nologo\n";
		print DSPFILE "\n";
		print DSPFILE "!ELSEIF  \"\$(CFG)\" == \"$name - Win32 Debug\"\n";
		print DSPFILE "\n";
		print DSPFILE "# PROP BASE Use_MFC 0\n";
		print DSPFILE "# PROP BASE Use_Debug_Libraries 1\n";
		print DSPFILE "# PROP BASE Output_Dir \"Debug\"\n";
		print DSPFILE "# PROP BASE Intermediate_Dir \"Debug\"\n";
		print DSPFILE "# PROP BASE Target_Dir \"\"\n";
		print DSPFILE "# PROP Use_MFC 0\n";
		print DSPFILE "# PROP Use_Debug_Libraries 1\n";
		print DSPFILE "# PROP Output_Dir \"Debug\"\n";
		print DSPFILE "# PROP Intermediate_Dir \"Debug\"\n";
		print DSPFILE "# PROP Ignore_Export_Lib 0\n";
		print DSPFILE "# PROP Target_Dir \"\"\n";
		print DSPFILE "# ADD CPP /nologo /wd4996 /wd4786 /MTd /W3 /Gm /GX /ZI /Od /YX /FD /GZ /c $includes $debDefines\n";
		print DSPFILE "# ADD LINK32 $debLibs $debExLibs /nologo $subsystem /debug /machine:I386 /pdbtype:sept \n";
		print DSPFILE "\n";
		print DSPFILE "# ADD MTL /nologo /D \"_DEBUG\" /mktyplib203 /win32\n";
		print DSPFILE "# ADD RSC /l 0x409 /d \"_DEBUG\"\n";
		print DSPFILE "# ADD BSC32 /nologo\n";
		print DSPFILE "\n";
		print DSPFILE "!ENDIF \n";
		print DSPFILE "\n";

		print DSPFILE "# Begin Target\n";
		print DSPFILE "# Name \"$name - Win32 Release\"\n";
		print DSPFILE "# Name \"$name - Win32 Debug\"\n";

			print DSPFILE "# Begin Group \"Source\"\n";
			print DSPFILE "# PROP Default_Filter \"cpp;c;cxx;rc;def;r;odl;idl;hpj;bat\"\n";

			foreach( @files ) {
				if( $_ !~ /\.h/ && $_ ) {
					print DSPFILE "# Begin Source File\n";
					print DSPFILE "SOURCE=";
					print DSPFILE "./";
					if( File::Spec->file_name_is_absolute($_) ) {
						$_ = File::Spec->abs2rel($_);
					}
					print DSPFILE "$_\n";
					print DSPFILE "# End Source File\n";
				}
			}

			print DSPFILE "# End Group\n";

			print DSPFILE "# Begin Group \"Headers\"\n";
			print DSPFILE "# PROP Default_Filter \"cpp;c;cxx;rc;def;r;odl;idl;hpj;bat\"\n";

			foreach( @files ) {
				if( $_ =~ /\.h/ && $_ ) {
					print DSPFILE "# Begin Source File\n";
					print DSPFILE "SOURCE=";
					print DSPFILE "./";
					if( File::Spec->file_name_is_absolute($_) ) {
						$_ = File::Spec->abs2rel($_);
					}
					print DSPFILE "$_\n";
					print DSPFILE "# End Source File\n";
				}
			}

			print DSPFILE "# End Group\n";

		print DSPFILE "# End Target\n";
	print DSPFILE "# End Project\n";

	close( DSPFILE );
}


sub win32_createMakefile_VC90 {
	my %hash = @_;

	my @files = @{ $hash{files} };

	# CHECK for icon
	# If there's an icon file then we have to generate a resource.rc file and include it

	my $includeRC = 0;
	if( $hash{win32icon} ) {
		$includeRC = 1;
		open( RC, ">$buildDir/zlab.rc" );
		print RC "101 ICON \"$hash{win32icon}\"";
		close RC;
	}

	my $name = "zlab";

	my $includes;

	map{ $_ =~ tr#/#\\#; $includes .= "$_," } uniquify( @{$hash{includes}} );
	my $debLibs;
	my $relLibs;
	my $debExLibs;
	my $relExLibs;
	my $debDefines;
	my $relDefines;
	map{ $_ =~ tr#/#\\#; $debDefines .= ";$_" } uniquify( @{ $hash{win32debugdefines} } );
	map{ $_ =~ tr#/#\\#; $relDefines .= ";$_" } uniquify( @{ $hash{win32releasedefines} } );
	map{ $_ =~ tr#/#\\#; } uniquify @files;
	$debDefines =~ s#\"#\\&quot;#g;
	$relDefines =~ s#\"#\\&quot;#g;

	map{ $_ =~ tr#/#\\#; $debLibs .= " $_ " } uniquify( (@{ $hash{win32debuglibs} }) );
	map{ $_ =~ tr#/#\\#; $relLibs .= " $_ " } uniquify( (@{ $hash{win32releaselibs} }) );
	map{ $_ =~ tr#/#\\#; $debExLibs .= "$_," } uniquify( @{ $hash{win32debugexcludelibs} } );
	map{ $_ =~ tr#/#\\#; $relExLibs .= " $_," } uniquify( @{ $hash{win32releaseexcludelibs} } );
	my $subsystem = $hash{interface} eq 'console' ? '1' : '2';
	my $console = $hash{interface} eq 'console' ? "_CONSOLE" : "";

	open( VCPROJFILE, ">$name.vcproj" );

	print VCPROJFILE <<ENDOFVCPROJ;
<?xml version="1.0" encoding="Windows-1252"?>
		<VisualStudioProject
			ProjectType="Visual C++"
			Version="9.00"
			Name="$name"
			ProjectGUID="{C1F930F6-6E43-419A-ADF7-DF155CC1246A}"
			TargetFrameworkVersion="0"
			>
			<Platforms>
				<Platform
					Name="Win32"
				/>
			</Platforms>
			<ToolFiles>
			</ToolFiles>
			<Configurations>
				<Configuration
					Name="Debug|Win32"
					OutputDirectory=".\\Debug"
					IntermediateDirectory=".\\Debug"
					ConfigurationType="1"
					InheritedPropertySheets="\$(VCInstallDir)VCProjectDefaults\\UpgradeFromVC60.vsprops"
					UseOfMFC="0"
					ATLMinimizesCRunTimeLibraryUsage="false"
					CharacterSet="2"
					>
					<Tool
						Name="VCPreBuildEventTool"
					/>
					<Tool
						Name="VCCustomBuildTool"
					/>
					<Tool
						Name="VCXMLDataGeneratorTool"
					/>
					<Tool
						Name="VCWebServiceProxyGeneratorTool"
					/>
					<Tool
						Name="VCMIDLTool"
						PreprocessorDefinitions="_DEBUG"
						MkTypLibCompatible="true"
						SuppressStartupBanner="true"
						TargetEnvironment="1"
						TypeLibraryName=".\\Debug\\$name.tlb"
						HeaderFileName=""
					/>
					<Tool
						Name="VCCLCompilerTool"
						AdditionalOptions="/wd4996 /wd4786 "
						Optimization="0"
						AdditionalIncludeDirectories="$includes"
						PreprocessorDefinitions="POINTER_64=__ptr64;_CRT_SECURE_NO_WARNINGS=1;WIN32;_DEBUG;_WINDOWS;$debDefines;$console"
						MinimalRebuild="true"
						BasicRuntimeChecks="3"
						RuntimeLibrary="1"
						PrecompiledHeaderFile=".\\Debug/$name.pch"
						AssemblerListingLocation=".\\Debug/"
						ObjectFile=".\\Debug/"
						ProgramDataBaseFileName=".\\Debug/"
						WarningLevel="3"
						SuppressStartupBanner="true"
						DebugInformationFormat="4"
					/>
					<Tool
						Name="VCManagedResourceCompilerTool"
					/>
					<Tool
						Name="VCResourceCompilerTool"
						PreprocessorDefinitions="_DEBUG"
						Culture="1033"
					/>
					<Tool
						Name="VCPreLinkEventTool"
					/>
					<Tool
						Name="VCLinkerTool"
						AdditionalDependencies="$debLibs"
						OutputFile=".\\Debug\\$name.exe"
						LinkIncremental="2"
						SuppressStartupBanner="true"
						IgnoreDefaultLibraryNames="$debExLibs"
						GenerateDebugInformation="true"
						ProgramDatabaseFile=".\\Debug\\$name.pdb"
						SubSystem="$subsystem"
						RandomizedBaseAddress="1"
						DataExecutionPrevention="0"
						TargetMachine="1"
					/>
					<Tool
						Name="VCALinkTool"
					/>
					<Tool
						Name="VCManifestTool"
					/>
					<Tool
						Name="VCXDCMakeTool"
					/>
					<Tool
						Name="VCBscMakeTool"
						SuppressStartupBanner="true"
						OutputFile=".\\Debug\\$name.bsc"
					/>
					<Tool
						Name="VCFxCopTool"
					/>
					<Tool
						Name="VCAppVerifierTool"
					/>
					<Tool
						Name="VCPostBuildEventTool"
					/>
				</Configuration>
				<Configuration
					Name="Release|Win32"
					OutputDirectory=".\\Release"
					IntermediateDirectory=".\\Release"
					ConfigurationType="1"
					InheritedPropertySheets="\$(VCInstallDir)VCProjectDefaults\\UpgradeFromVC60.vsprops"
					UseOfMFC="0"
					ATLMinimizesCRunTimeLibraryUsage="false"
					CharacterSet="2"
					>
					<Tool
						Name="VCPreBuildEventTool"
					/>
					<Tool
						Name="VCCustomBuildTool"
					/>
					<Tool
						Name="VCXMLDataGeneratorTool"
					/>
					<Tool
						Name="VCWebServiceProxyGeneratorTool"
					/>
					<Tool
						Name="VCMIDLTool"
						PreprocessorDefinitions="NDEBUG"
						MkTypLibCompatible="true"
						SuppressStartupBanner="true"
						TargetEnvironment="1"
						TypeLibraryName=".\\Release\\$name.tlb"
						HeaderFileName=""
					/>
					<Tool
						Name="VCCLCompilerTool"
						AdditionalOptions="/wd4996 /wd4786 "
						Optimization="2"
						InlineFunctionExpansion="1"
						AdditionalIncludeDirectories="$includes"
						PreprocessorDefinitions="POINTER_64=__ptr64;_CRT_SECURE_NO_WARNINGS=1;NDEBUG;WIN32;_WINDOWS;$relDefines;$console"
						StringPooling="true"
						RuntimeLibrary="0"
						EnableFunctionLevelLinking="true"
						PrecompiledHeaderFile=".\\Release\\$name.pch"
						AssemblerListingLocation=".\\Release/"
						ObjectFile=".\\Release/"
						ProgramDataBaseFileName=".\\Release/"
						BrowseInformation="1"
						WarningLevel="3"
						SuppressStartupBanner="true"
						DebugInformationFormat="3"
					/>
					<Tool
						Name="VCManagedResourceCompilerTool"
					/>
					<Tool
						Name="VCResourceCompilerTool"
						PreprocessorDefinitions="NDEBUG"
						Culture="1033"
					/>
					<Tool
						Name="VCPreLinkEventTool"
					/>
					<Tool
						Name="VCLinkerTool"
						AdditionalDependencies="$relLibs"
						OutputFile=".\\Release\\$name.exe"
						LinkIncremental="2"
						SuppressStartupBanner="true"
						IgnoreDefaultLibraryNames="$relExLibs"
						GenerateDebugInformation="true"
						ProgramDatabaseFile=".\\Release\\$name.pdb"
						SubSystem="$subsystem"
						RandomizedBaseAddress="1"
						DataExecutionPrevention="0"
						TargetMachine="1"
					/>
					<Tool
						Name="VCALinkTool"
					/>
					<Tool
						Name="VCManifestTool"
					/>
					<Tool
						Name="VCXDCMakeTool"
					/>
					<Tool
						Name="VCBscMakeTool"
						SuppressStartupBanner="true"
						OutputFile=".\\Release\\$name.bsc"
					/>
					<Tool
						Name="VCFxCopTool"
					/>
					<Tool
						Name="VCAppVerifierTool"
					/>
					<Tool
						Name="VCPostBuildEventTool"
					/>
				</Configuration>
			</Configurations>
			<References>
			</References>

ENDOFVCPROJ


	print VCPROJFILE "<Files>\n";

	#
	# DUMP the cpp files classifying to zbslib, plugins and everything sg
	#

	sub dumpFile {
		if( File::Spec->file_name_is_absolute($file) ) {
			$file = File::Spec->abs2rel($file);
		}
		$file =~ tr#/#\\#;
		
		print VCPROJFILE <<ENDOFVCPROJ;
			<File RelativePath="$file">
				<FileConfiguration Name="Debug|Win32">
					<Tool Name="VCCLCompilerTool" AdditionalIncludeDirectories="" PreprocessorDefinitions="" />
				</FileConfiguration>
				<FileConfiguration Name="Release|Win32" >
					<Tool Name="VCCLCompilerTool" AdditionalIncludeDirectories="" PreprocessorDefinitions="" />
				</FileConfiguration>
			</File>
ENDOFVCPROJ
	}

	# DUMP zbslib
	print VCPROJFILE "	<Filter Name=\"zbslib\">\n";
	foreach $file (@files) {
		if( $file && $file !~ /\.h/ && $file =~ /zbslib/ ) {
			dumpFile();
		}
	}
	print VCPROJFILE "</Filter>\n";

	# DUMP plugins
	print VCPROJFILE "	<Filter Name=\"plugins\">\n";
	foreach $file (@files) {
		$filename = (File::Spec->splitpath( $file ))[2];
		if( $file && $file !~ /\.h/ && $file !~ /zbslib/ && $filename =~ /^_/ ) {
			dumpFile();
		}
	}
	print VCPROJFILE "</Filter>\n";

	# DUMP everything else
	print VCPROJFILE "	<Filter Name=\"main\">\n";
	foreach $file (@files) {
		$filename = (File::Spec->splitpath( $file ))[2];
		if( $file && $file !~ /\.h/ && $file !~ /zbslib/ && $filename !~ /^_/ ) {
			dumpFile();
		}
	}
	
	print VCPROJFILE "</Filter>\n";

	# DUMP the headers
	print VCPROJFILE "<Filter Name=\"Headers\">\n";
	foreach $file (@files) {
		$filename = (File::Spec->splitpath( $file ))[2];
		if( $file && $file =~ /\.h/ ) {
			if( File::Spec->file_name_is_absolute($file) ) {
				$file = File::Spec->abs2rel($file);
			}
			print VCPROJFILE "<File RelativePath=\"$file\"></File>\n";
		}
	}
	print VCPROJFILE "</Filter>\n";

	if( $includeRC ) {
		print VCPROJFILE "<File RelativePath=\".\\zlab.rc\"></File>\n";
	}

	print VCPROJFILE "</Files>\n";
	print VCPROJFILE "<Globals></Globals>\n";
	print VCPROJFILE "</VisualStudioProject>\n";

	close( VCPROJFILE );
}

sub win32_createMakefile_VC120 {
	#
	# THIS IS A TEMPORARY SOLUTION FOR BUILDING A 64BIT VERSION OF THE KINTEK SOFTWARE.
	# IT WRITES A COPY OF THE 12.0 FORMAT .VCXPROJ FILE THAT WAS PRODUCED BY UPGRADING
	# THE 9.0 FORMAT USING A TOOL.  THIS IS HARDCODED FOR ONLY THE KINTEK PROJECT,
	# AND ONLY THE DEV VERSION AT THAT.
	#

	my %hash = @_;

	my @files = @{ $hash{files} };

	# CHECK for icon
	# If there's an icon file then we have to generate a resource.rc file and include it

	my $includeRC = 0;
	if( $hash{win32icon} ) {
		$includeRC = 1;
		open( RC, ">$buildDir/zlab.rc" );
		print RC "101 ICON \"$hash{win32icon}\"";
		close RC;
	}

	my $name = "zlab";

	my $includes;

	map{ $_ =~ tr#/#\\#; $includes .= "$_;" } uniquify( @{$hash{includes}} );
	my $debLibs;
	my $relLibs;
	my $debExLibs;
	my $relExLibs;
	my $debDefines;
	my $relDefines;
	map{ $_ =~ tr#/#\\#; $debDefines .= "$_;" } uniquify( @{ $hash{win32debugdefines} } );
	map{ $_ =~ tr#/#\\#; $relDefines .= "$_;" } uniquify( @{ $hash{win32releasedefines} } );
	map{ $_ =~ tr#/#\\#; } uniquify @files;
#	$debDefines =~ s#\"#\\&quot;#g;
#	$relDefines =~ s#\"#\\&quot;#g;

	map{ $_ =~ tr#/#\\#; $debLibs .= " $_;" } uniquify( (@{ $hash{win32debuglibs} }) );
	map{ $_ =~ tr#/#\\#; $relLibs .= " $_;" } uniquify( (@{ $hash{win32releaselibs} }) );
	map{ $_ =~ tr#/#\\#; $debExLibs .= "$_;" } uniquify( @{ $hash{win32debugexcludelibs} } );
	map{ $_ =~ tr#/#\\#; $relExLibs .= "$_;" } uniquify( @{ $hash{win32releaseexcludelibs} } );
	my $subsystem = $hash{interface} eq 'console' ? '1' : '2';
	my $console = $hash{interface} eq 'console' ? "_CONSOLE" : "";

	open( VCPROJFILE, ">$name.vcxproj" );

	print VCPROJFILE <<ENDOFVCPROJ;
<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" ToolsVersion="12.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup Label="ProjectConfigurations">
    <ProjectConfiguration Include="Debug|Win32">
      <Configuration>Debug</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Debug|x64">
      <Configuration>Debug</Configuration>
      <Platform>x64</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|Win32">
      <Configuration>Release</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|x64">
      <Configuration>Release</Configuration>
      <Platform>x64</Platform>
    </ProjectConfiguration>
  </ItemGroup>
  <PropertyGroup Label="Globals">
    <ProjectGuid>{C1F930F6-6E43-419A-ADF7-DF155CC1246A}</ProjectGuid>
  </PropertyGroup>
  <Import Project="\$(VCTargetsPath)\\Microsoft.Cpp.Default.props" />
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'" Label="Configuration">
    <ConfigurationType>Application</ConfigurationType>
    <PlatformToolset>v120</PlatformToolset>
    <UseOfMfc>false</UseOfMfc>
    <CharacterSet>MultiByte</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'" Label="Configuration">
    <ConfigurationType>Application</ConfigurationType>
    <PlatformToolset>v120</PlatformToolset>
    <UseOfMfc>false</UseOfMfc>
    <CharacterSet>MultiByte</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'" Label="Configuration">
    <ConfigurationType>Application</ConfigurationType>
    <PlatformToolset>v120</PlatformToolset>
    <UseOfMfc>false</UseOfMfc>
    <CharacterSet>MultiByte</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'" Label="Configuration">
    <ConfigurationType>Application</ConfigurationType>
    <PlatformToolset>v120</PlatformToolset>
    <UseOfMfc>false</UseOfMfc>
    <CharacterSet>MultiByte</CharacterSet>
  </PropertyGroup>
  <Import Project="\$(VCTargetsPath)\\Microsoft.Cpp.props" />
  <ImportGroup Label="ExtensionSettings">
  </ImportGroup>
  <ImportGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'" Label="PropertySheets">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
    <Import Project="\$(VCTargetsPath)Microsoft.CPP.UpgradeFromVC60.props" />
  </ImportGroup>
  <ImportGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'" Label="PropertySheets">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
    <Import Project="\$(VCTargetsPath)Microsoft.CPP.UpgradeFromVC60.props" />
  </ImportGroup>
  <ImportGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'" Label="PropertySheets">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
    <Import Project="\$(VCTargetsPath)Microsoft.CPP.UpgradeFromVC60.props" />
  </ImportGroup>
  <ImportGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'" Label="PropertySheets">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
    <Import Project="\$(VCTargetsPath)Microsoft.CPP.UpgradeFromVC60.props" />
  </ImportGroup>
  <PropertyGroup Label="UserMacros" />
  <PropertyGroup>
    <_ProjectFileVersion>12.0.30501.0</_ProjectFileVersion>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'">
    <OutDir>.\\Debug\\</OutDir>
    <IntDir>.\\Debug\\</IntDir>
    <LinkIncremental>true</LinkIncremental>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'">
    <LinkIncremental>true</LinkIncremental>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'">
    <OutDir>.\\Release\\</OutDir>
    <IntDir>.\\Release\\</IntDir>
    <LinkIncremental>true</LinkIncremental>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'">
    <LinkIncremental>true</LinkIncremental>
  </PropertyGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'">
    <Midl>
      <PreprocessorDefinitions>_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <MkTypLibCompatible>true</MkTypLibCompatible>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <TargetEnvironment>Win32</TargetEnvironment>
      <TypeLibraryName>.\\Debug\\zlab.tlb</TypeLibraryName>
      <HeaderFileName />
    </Midl>
    <ClCompile>
      <AdditionalOptions>/wd4996 /wd4786  %(AdditionalOptions)</AdditionalOptions>
      <Optimization>Disabled</Optimization>
      <AdditionalIncludeDirectories>$includes%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
      <PreprocessorDefinitions>POINTER_64=__ptr64;_CRT_SECURE_NO_WARNINGS=1;WIN32;_DEBUG;_WINDOWS;$debDefines$console;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <MinimalRebuild>true</MinimalRebuild>
      <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
      <PrecompiledHeaderOutputFile>.\\Debug/zlab.pch</PrecompiledHeaderOutputFile>
      <AssemblerListingLocation>.\\Debug/</AssemblerListingLocation>
      <ObjectFileName>.\\Debug/</ObjectFileName>
      <ProgramDataBaseFileName>.\\Debug/</ProgramDataBaseFileName>
      <WarningLevel>Level3</WarningLevel>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <DebugInformationFormat>EditAndContinue</DebugInformationFormat>
    </ClCompile>
    <ResourceCompile>
      <PreprocessorDefinitions>_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <Culture>0x0409</Culture>
    </ResourceCompile>
    <Link>
      <AdditionalDependencies>$debLibs%(AdditionalDependencies)</AdditionalDependencies>
      <OutputFile>.\\Debug\\zlab.exe</OutputFile>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <IgnoreSpecificDefaultLibraries>$debExLibs%(IgnoreSpecificDefaultLibraries)</IgnoreSpecificDefaultLibraries>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <ProgramDatabaseFile>.\\Debug\\zlab.pdb</ProgramDatabaseFile>
      <SubSystem>Windows</SubSystem>
      <RandomizedBaseAddress>false</RandomizedBaseAddress>
      <DataExecutionPrevention />
      <TargetMachine>MachineX86</TargetMachine>
    </Link>
    <Bscmake>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <OutputFile>.\\Debug\\zlab.bsc</OutputFile>
    </Bscmake>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'">
    <Midl>
      <PreprocessorDefinitions>_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <MkTypLibCompatible>true</MkTypLibCompatible>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <TypeLibraryName>.\\Debug\\zlab.tlb</TypeLibraryName>
      <HeaderFileName>
      </HeaderFileName>
    </Midl>
    <ClCompile>
      <AdditionalOptions>/wd4996 /wd4786  %(AdditionalOptions)</AdditionalOptions>
      <Optimization>Disabled</Optimization>
      <AdditionalIncludeDirectories>$includes%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
      <PreprocessorDefinitions>POINTER_64=__ptr64;_CRT_SECURE_NO_WARNINGS=1;WIN32;_DEBUG;_WINDOWS;$debDefines$console;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
      <PrecompiledHeaderOutputFile>.\\Debug/zlab.pch</PrecompiledHeaderOutputFile>
      <AssemblerListingLocation>.\\Debug/</AssemblerListingLocation>
      <ObjectFileName>.\\Debug/</ObjectFileName>
      <ProgramDataBaseFileName>.\\Debug/</ProgramDataBaseFileName>
      <WarningLevel>Level3</WarningLevel>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
    </ClCompile>
    <ResourceCompile>
      <PreprocessorDefinitions>_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <Culture>0x0409</Culture>
    </ResourceCompile>
    <Link>
      <AdditionalDependencies>$debLibs%(AdditionalDependencies)</AdditionalDependencies>
      <OutputFile>.\\Debug\\zlab.exe</OutputFile>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <IgnoreSpecificDefaultLibraries>$debExLibs%(IgnoreSpecificDefaultLibraries)</IgnoreSpecificDefaultLibraries>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <ProgramDatabaseFile>.\\Debug\\zlab.pdb</ProgramDatabaseFile>
      <SubSystem>Windows</SubSystem>
      <RandomizedBaseAddress>false</RandomizedBaseAddress>
      <DataExecutionPrevention>
      </DataExecutionPrevention>
    </Link>
    <Bscmake>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <OutputFile>.\\Debug\\zlab.bsc</OutputFile>
    </Bscmake>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'">
    <Midl>
      <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <MkTypLibCompatible>true</MkTypLibCompatible>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <TargetEnvironment>Win32</TargetEnvironment>
      <TypeLibraryName>.\\Release\\zlab.tlb</TypeLibraryName>
      <HeaderFileName />
    </Midl>
    <ClCompile>
      <AdditionalOptions>/wd4996 /wd4786  %(AdditionalOptions)</AdditionalOptions>
      <Optimization>MaxSpeed</Optimization>
      <InlineFunctionExpansion>OnlyExplicitInline</InlineFunctionExpansion>
      <AdditionalIncludeDirectories>$includes%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
      <PreprocessorDefinitions>POINTER_64=__ptr64;_CRT_SECURE_NO_WARNINGS=1;NDEBUG;WIN32;_WINDOWS;$relDefines$console;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <StringPooling>true</StringPooling>
      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
      <FunctionLevelLinking>true</FunctionLevelLinking>
      <PrecompiledHeaderOutputFile>.\\Release\\zlab.pch</PrecompiledHeaderOutputFile>
      <AssemblerListingLocation>.\\Release/</AssemblerListingLocation>
      <ObjectFileName>.\\Release/</ObjectFileName>
      <ProgramDataBaseFileName>.\\Release/</ProgramDataBaseFileName>
      <BrowseInformation>true</BrowseInformation>
      <WarningLevel>Level3</WarningLevel>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
    </ClCompile>
    <ResourceCompile>
      <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <Culture>0x0409</Culture>
    </ResourceCompile>
    <Link>
      <AdditionalDependencies>$relLibs%(AdditionalDependencies)</AdditionalDependencies>
      <OutputFile>.\\Release\\zlab.exe</OutputFile>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <IgnoreSpecificDefaultLibraries>$relExLibs%(IgnoreSpecificDefaultLibraries)</IgnoreSpecificDefaultLibraries>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <ProgramDatabaseFile>.\\Release\\zlab.pdb</ProgramDatabaseFile>
      <SubSystem>Windows</SubSystem>
      <RandomizedBaseAddress>false</RandomizedBaseAddress>
      <DataExecutionPrevention />
      <TargetMachine>MachineX86</TargetMachine>
    </Link>
    <Bscmake>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <OutputFile>.\\Release\\zlab.bsc</OutputFile>
    </Bscmake>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'">
    <Midl>
      <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <MkTypLibCompatible>true</MkTypLibCompatible>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <TypeLibraryName>.\\Release\\zlab.tlb</TypeLibraryName>
      <HeaderFileName>
      </HeaderFileName>
    </Midl>
    <ClCompile>
      <AdditionalOptions>/wd4996 /wd4786  %(AdditionalOptions)</AdditionalOptions>
      <Optimization>MaxSpeed</Optimization>
      <InlineFunctionExpansion>OnlyExplicitInline</InlineFunctionExpansion>
      <AdditionalIncludeDirectories>$includes%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
      <PreprocessorDefinitions>POINTER_64=__ptr64;_CRT_SECURE_NO_WARNINGS=1;NDEBUG;WIN32;_WINDOWS;$relDefines$console;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <StringPooling>true</StringPooling>
      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
      <FunctionLevelLinking>true</FunctionLevelLinking>
      <PrecompiledHeaderOutputFile>.\\Release\\zlab.pch</PrecompiledHeaderOutputFile>
      <AssemblerListingLocation>.\\Release/</AssemblerListingLocation>
      <ObjectFileName>.\\Release/</ObjectFileName>
      <ProgramDataBaseFileName>.\\Release/</ProgramDataBaseFileName>
      <BrowseInformation>true</BrowseInformation>
      <WarningLevel>Level3</WarningLevel>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
    </ClCompile>
    <ResourceCompile>
      <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <Culture>0x0409</Culture>
    </ResourceCompile>
    <Link>
      <AdditionalDependencies>$relLibs%(AdditionalDependencies)</AdditionalDependencies>
      <OutputFile>.\\Release\\zlab.exe</OutputFile>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <IgnoreSpecificDefaultLibraries>$relExLibs%(IgnoreSpecificDefaultLibraries)</IgnoreSpecificDefaultLibraries>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <ProgramDatabaseFile>.\\Release\\zlab.pdb</ProgramDatabaseFile>
      <SubSystem>Windows</SubSystem>
      <RandomizedBaseAddress>false</RandomizedBaseAddress>
      <DataExecutionPrevention>
      </DataExecutionPrevention>
    </Link>
    <Bscmake>
      <SuppressStartupBanner>true</SuppressStartupBanner>
      <OutputFile>.\\Release\\zlab.bsc</OutputFile>
    </Bscmake>
  </ItemDefinitionGroup>
ENDOFVCPROJ

	#
	# Dump source files to VCPROJ
	#
	print VCPROJFILE "\t<ItemGroup>\n";
	foreach $file( @files ) {
		if( $file && $file !~ /\.h/ ) {
			if( File::Spec->file_name_is_absolute($file) ) {
				$file = File::Spec->abs2rel($file);
			}
			$file =~ tr#/#\\#;	
			print VCPROJFILE "\t\t<ClCompile Include=\"$file\" />\n";
		}
	}
	print VCPROJFILE "\t</ItemGroup>\n";

	#
	# Dump headers to VCPROJ
	#
	print VCPROJFILE "\t<ItemGroup>";
	foreach $file( @files ) {
		if( $file && $file =~ /\.h/ ) {
			if( File::Spec->file_name_is_absolute($file) ) {
				$file = File::Spec->abs2rel($file);
			}
			$file =~ tr#/#\\#;
			print VCPROJFILE "\t\t<ClInclude Include=\"$file\" />\n";
		}
	}
	print VCPROJFILE "\t</ItemGroup>\n";
 
    print VCPROJFILE <<ENDOFVCPROJ;
  <ItemGroup>
    <ResourceCompile Include="zlab.rc" />
  </ItemGroup>
  <Import Project="\$(VCTargetsPath)\\Microsoft.Cpp.targets" />
  <ImportGroup Label="ExtensionTargets">
  </ImportGroup>
</Project>
ENDOFVCPROJ

	close( VCPROJFILE );

	#
	# vs2013 (vc12) employs a separate "filters" file that controls the display of
	# files in different subfolders in the project. 
	#
=TODO if we need this.

	open( VCPROJFILTERS, ">$name.vcxproj.filters" ); 
	print VCPROJFILTERS <<ENDOFVCPROJFILTERS;
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
    <Filter Include="zbslib">
      <UniqueIdentifier>{763e0e62-65dc-424f-8fc4-4fd2e80ed51d}</UniqueIdentifier>
    </Filter>
    <Filter Include="plugins">
      <UniqueIdentifier>{281e0e96-c7bb-454d-b86f-4c4f23a0ba66}</UniqueIdentifier>
    </Filter>
    <Filter Include="main">
      <UniqueIdentifier>{1a3ad70b-8c2b-4834-821a-91090c979ebb}</UniqueIdentifier>
    </Filter>
    <Filter Include="Headers">
      <UniqueIdentifier>{508ba622-db92-4938-82bf-06d21c087c2b}</UniqueIdentifier>
    </Filter>
  </ItemGroup>
ENDOFVCPROJFILTERS

	#
	# zbslib
	#
	print VCPROJFILTERS "\t<ItemGroup>";
	foreach $file( @files ) {
		$filename = (File::Spec->splitpath( $file ))[2];
		if( $file && $file =~ /zbslib/ ) {
			if( File::Spec->file_name_is_absolute($file) ) {
				$file = File::Spec->abs2rel($file);
			}
			print VCPROJFILTERS "\t\t<ClInclude Include=\"$file\" />\n";
		}
	}
	print VCPROJFILTERS "\t</ItemGroup>";
 
	# etc - other filter blocks here

	print VCPROJFILTERS <<ENDOFVCPROJFILTERS;
  <ItemGroup>
    <ResourceCompile Include="zlab.rc" />
  </ItemGroup>
</Project>
ENDOFVCPROJFILTERS

=cut

}

sub linux_createMakefile {
	my %hash = @_;

	open( MAKEFILE, ">Makefile" );
	print MAKEFILE "PROGRAM = zlab\n";
	print MAKEFILE "\n";
	print MAKEFILE "INCLUDES = \\\n";
	map{ $_ =~ tr#\\#/#; print MAKEFILE "\t-I$_ \\\n" } uniquify( @{$hash{includes}} );
	print MAKEFILE "\n";
	print MAKEFILE "LIBS = \\\n";
	print MAKEFILE "\t-lpthread \\\n";
		# always link to pthread even if not explicit depends; new linux distros I've tried seem to
		# want pthread from the x11 stuff we link to? (tfb)
	map{ $_ =~ tr#\\#/#; print MAKEFILE "\t$_ \\\n" } uniquify( @{$hash{linuxlibs}} );
	print MAKEFILE "\n";
	print MAKEFILE "SRC_FILES = \\\n";
	map{ $_ =~ tr#\\#/#; print MAKEFILE "\t$_ \\\n" if( $_ !~ /\.h/ ) } uniquify( @{$hash{files}} );
	print MAKEFILE "\n";
	print MAKEFILE "DEFINES = -D __USE_GNU -D _GNU_SOURCE \\\n";
	foreach( uniquify( @{$hash{linuxdefines}} ) ) {
		if( /(.*)=\s*\"(.*)\"/ ) {
			# Good grief!
			$_ = "$1=\"\\\"$2\\\"\"";
		}
		print MAKEFILE "  -D $_ \\\n";
	}
#	map{ s#\"([^\"]*)\"##g; print MAKEFILE "  -D $_ \\\n" } uniquify( @{$hash{linuxdefines}} );
	print MAKEFILE "\n";
	print MAKEFILE "OBJS1 = \$(SRC_FILES)\n";
	print MAKEFILE "OBJS2 = \$(subst .cpp,.o,\$(OBJS1))\n";
	print MAKEFILE "OBJS = \$(subst .c,.o,\$(OBJS2))\n";
	print MAKEFILE "\n";
	print MAKEFILE "CC = g++\n";
	print MAKEFILE "\n";
	print MAKEFILE "CFLAGS = -g -O3 \$(INCLUDES)  -Wno-write-strings\n";
	print MAKEFILE "\n";
	print MAKEFILE "#####################################################################################################\n";
	print MAKEFILE "\n";
	print MAKEFILE "all: \$(PROGRAM)\n";
	print MAKEFILE "\n";
	print MAKEFILE "\%.o : \%.cpp\n";
	print MAKEFILE "\t\@echo \$<\n";
	print MAKEFILE "\t\@\$(CC) \$(CFLAGS) \$(DEFINES) -fpermissive -Wno-non-template-friend -c \$< -o \$@\n";
	print MAKEFILE "\n";
	my $wroteCMessage = 0;
	foreach ( sort uniquify( @{$hash{files}} ) ) {
		if( /\.c$/ ) {
			if( ! $wroteCMessage ) {
				print MAKEFILE "### .c files must have explicit rules since the above rule only covers .cpp files\n";
				$wroteCMessage++;
			}
			my $o = $_;
			$o =~ s/\.c$/\.o/;
			print MAKEFILE "$o : $_\n";
			print MAKEFILE "\t\@echo \$<\n";
			print MAKEFILE "\t\@gcc \$(CFLAGS) -c \$< -o \$\@\n";
			print MAKEFILE "\n";
		}
	}
	print MAKEFILE "\$(PROGRAM): \$(OBJS)\n";
	print MAKEFILE "\t\@libtool --mode=link \$(CC) \$(CFLAGS) \$^ -o \$\@ \$(LIB_DIRS) \$(LIBS)\n";
	print MAKEFILE "\t\@echo ==============================================\n";
	print MAKEFILE "\t\@echo ================= SUCCESS ====================\n";
	print MAKEFILE "\t\@echo ============= To run: ./zlab =================\n";
	print MAKEFILE "\t\@echo ==============================================\n";
	print MAKEFILE "\n";
	print MAKEFILE "clean: #depend\n";
	print MAKEFILE "\trm -f \$(OBJS)\n";
	print MAKEFILE "\trm -f \$(PROGRAM)\n";
	print MAKEFILE "\n";
	print MAKEFILE "#depend:\n";
	print MAKEFILE "#\tmakedepend \$(CFLAGS) \$(DEFINES) \$(SRC_CORE) \$(SRC_PLUGINS) \$(SRC_ZBSLIB)\n";

	close( MAKEFILE );
}

sub macosx_createMakefile {
	my %hash = @_;
	
	my $optimize = "-O3";
	my $compiler = 'g++';
	my $minVersion = "10.10";
	my $windowLib  = "Cocoa";

	# On 64bit osx, for some native Cocoa-based functionality we must use objective-C - since this
	# is the only module and only applies to 64bit osx, it seemed simplest to just make that replacement
	# here.  It is noted in the ZBS module record for filedialog_native.cpp
	my $files = join( ':', @{$hash{files}} );
	$files =~ s/filedialog_native.cpp/filedialog_native.mm/g;
	@{$hash{files}} = split( /:/, $files );

	open( MAKEFILE, ">Makefile" );
	print MAKEFILE "PROGRAM = $hash{name}App\n";
	print MAKEFILE "\n";
	print MAKEFILE "INCLUDES = \\\n";
	map{ $_ =~ tr#\\#/#; print MAKEFILE "\t-I$_ \\\n" } uniquify( @{$hash{includes}} );
	print MAKEFILE "\n";
	print MAKEFILE "LIBS = \\\n";
	print MAKEFILE "\t-lpthread \\\n";
		# the above is a nasty hack by tfb: if we don't link to some library with the -l mechanism as above,
		# the static link to pcre will fail with undefined symbols for some unexplicable reason.  This only
		# happens on osx 10.4 in my tests.  So I always just add the link to pthread, whether needed or not.	
	map{ $_ =~ tr#\\#/#; print MAKEFILE "\t$_ \\\n" } uniquify( @{$hash{macosxlibs}} );
	print MAKEFILE "\n";
	print MAKEFILE "SRC_FILES = \\\n";
	map{ $_ =~ tr#\\#/#; print MAKEFILE "\t$_ \\\n" if( $_ !~ /\.h/ ) } uniquify( @{$hash{files}} );
	print MAKEFILE "\n";
	print MAKEFILE "DEFINES = -D __USE_GNU -D _GNU_SOURCE \\\n";
	foreach( uniquify( @{$hash{macosxdefines}} ) ) {
		if( /(.*)=\s*\"(.*)\"/ ) {
			# Good grief!
			$_ = "$1=\"\\\"$2\\\"\"";
		}
		print MAKEFILE "  -D $_ \\\n";
	}
	print MAKEFILE "\n";
	print MAKEFILE "OBJS1 = \$(SRC_FILES)\n";
	print MAKEFILE "OBJS2 = \$(subst .cpp,.o,\$(OBJS1))\n";
	print MAKEFILE "OBJS3 = \$(subst .mm,.o,\$(OBJS2))\n";
	print MAKEFILE "OBJS = \$(subst .c,.o,\$(OBJS3))\n";
	print MAKEFILE "\n";
	print MAKEFILE "CC = $compiler\n";
	print MAKEFILE "\n";
	print MAKEFILE "CFLAGS = -g $optimize -stdlib=libstdc++ -fwritable-strings -Wno-write-strings -mmacosx-version-min=$minVersion \$(INCLUDES) \$(DEFINES)\n";
	print MAKEFILE "\n";
	print MAKEFILE "#####################################################################################################\n";
	print MAKEFILE "\n";
	print MAKEFILE "all: \$(PROGRAM)\n";
	print MAKEFILE "\n";
	print MAKEFILE "\%.o : \%.mm\n";
	print MAKEFILE "\t\@echo \$<\n";
	print MAKEFILE "\t\@\$(CC) \$(CFLAGS) -c \$< -o \$@\n";
	print MAKEFILE "\n";
	print MAKEFILE "\%.o : \%.cpp\n";
	print MAKEFILE "\t\@echo \$<\n";
	print MAKEFILE "\t\@\$(CC) \$(CFLAGS) -fpermissive -c \$< -o \$@\n";
	print MAKEFILE "\n";
	my $wroteCMessage = 0;
	foreach ( sort uniquify( @{$hash{files}} ) ) {
		if( /\.c$/ ) {
			if( ! $wroteCMessage ) {
				print MAKEFILE "### .c files must have explicit rules since the above rule only covers .cpp files\n";
				$wroteCMessage++;
			}
			my $o = $_;
			$o =~ s/\.c$/\.o/;
			print MAKEFILE "$o : $_\n";
			print MAKEFILE "\t\@echo \$<\n";
			print MAKEFILE "\t\@gcc \$(CFLAGS) -fpermissive -Wno-non-template-friend -c \$< -o \$\@\n";
			print MAKEFILE "\n";
		}
	}
	print MAKEFILE "\$(PROGRAM): \$(OBJS)\n";
	print MAKEFILE "\t\@\$(CC) \$(CFLAGS) \$^ \$(LIBS) -framework AGL -framework OpenGL -framework $windowLib -framework IOKit -framework CoreFoundation -framework CoreAudio -framework AudioUnit -framework AudioToolbox -framework CoreMIDI -o \$(PROGRAM)\n";
		#IOKit and CoreFoundation frameworks were added to support static linking to the Secutech usbkey library.
	print MAKEFILE "\t\@mkdir -p zlab.app/Contents/Resources\n";
	print MAKEFILE "\t\@mkdir -p zlab.app/Contents/MacOS\n";
	print MAKEFILE "\t\@" . 'echo \<\?xml version=\"1.0\" encoding=\"UTF-8\"\?\> > zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo \<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"\> >> zlab.app/Contents/Info.plist' . "\n"; 
	print MAKEFILE "\t\@" . 'echo \<plist version=\"1.0\"\> >> zlab.app/Contents/Info.plist' . "\n";;
	print MAKEFILE "\t\@" . 'echo \<dict\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<key\>CFBundleDevelopmentRegion\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>English\</string\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<key\>CFBundleExecutable\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>' . "$hash{name}" . '\</string\> >> zlab.app/Contents/Info.plist' . "\n";
	if( $hash{macosxicon} ) {
		print MAKEFILE "\t\@" . 'echo 	\<key\>CFBundleIconFile\</key\> >> zlab.app/Contents/Info.plist' . "\n";
		print MAKEFILE "\t\@" . 'echo 	\<string\>zlabApp.icns\</string\> >> zlab.app/Contents/Info.plist' . "\n";
		print MAKEFILE "\t\@cp $hash{macosxicon} zlab.app/Contents/Resources/zlabApp.icns\n";
	}	
	print MAKEFILE "\t\@" . 'echo   \<key\>CFBundleInfoDictionaryVersion\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>6.0\</string\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<key\>CFBundleName\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>' . "$hash{name}" . '\</string\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<key\>CFBundlePackageType\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>APPL\</string\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<key\>CFBundleSignature\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>????\</string\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<key\>CFBundleVersion\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>1\</string\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<key\>LSMinimumSystemVersion\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>' . "$minVersion" . '\</string\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<key\>NSPrincipalClass\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>NSApplication\</string\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<key\>NSHighResolutionCapable\</key\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo 	\<string\>True\</string\> >> zlab.app/Contents/Info.plist' . "\n";

	print MAKEFILE "\t\@" . 'echo \</dict\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@" . 'echo \</plist\> >> zlab.app/Contents/Info.plist' . "\n";
	print MAKEFILE "\t\@cp $hash{name}App zlab.app/Contents/MacOS/$hash{name}\n";
	print MAKEFILE "\t\@rm -f $hash{name}App\n";
	print MAKEFILE "\t\@echo ==============================================\n";
	print MAKEFILE "\t\@echo ================= SUCCESS ====================\n";
	print MAKEFILE "\t\@echo ============= To run: open zlab.app ==========\n";
	print MAKEFILE "\t\@echo ==============================================\n";		
	print MAKEFILE "\n";
	print MAKEFILE "clean: #depend\n";
	print MAKEFILE "\trm -f \$(OBJS)\n";
	print MAKEFILE "\trm -f \$(PROGRAM)\n";
	print MAKEFILE "\trm -rf zlab.app\n";
	print MAKEFILE "\trm -rf $hash{name}\n";
	print MAKEFILE "\n";
	print MAKEFILE "#depend:\n";
	print MAKEFILE "#\tmakedepend \$(CFLAGS) \$(SRC_CORE) \$(SRC_PLUGINS) \$(SRC_ZBSLIB)\n";

	close( MAKEFILE );
	
	# Create an xcode projectfile as well...
	#
	macosx_createMakefile_xcode3( @_);
}

my %fileRefGUID = {};
my %buildRefGUID = {};
my $guidCounter=0;
sub getXcodeGuid($) {
	my $filename = shift;
	if( ! $fileRefGUID{ $filename } ) {
		$buildRefGUID{ $filename } = "E92CD26B" . sprintf( "%08X", $guidCounter++ ) . "000BE31F";
		$fileRefGUID{ $filename }  = "E92CD26F" . sprintf( "%08X", $guidCounter ) . "000BE31F";
				# those are sample values taken from xcode project; not sure if significant
	}
	return ( $fileRefGUID{ $filename }, $buildRefGUID{ $filename } );
}

sub macosx_createMakefile_xcode3 {
	my %hash = @_;
	my @files = @{ $hash{files} };
	my $name = "zlab";
	
	$build64Bit = platformBuild64Bit();
	
	# for simplicity at present we add any frameworks that any of our plugins may need.  It would be more appropriate for sdks to
	# reference frameworks they depend on, since in general plugins will not call native osx frameworks, but rather the cross-platform
	# sdks will depend on them (e.g. )
	my $windowLib = $build64Bit ? "Cocoa" : "Carbon";
	my @sysframeworks = (
		"CoreFoundation",    						# most/all zlab apps would need this
		$windowLib, "AGL", "OpenGL",				# gui opengl based apps need these
		"IOKit",									# apps that use usb-based keys need this
		"CoreAudio", "AudioUnit", "AudioToolbox", "CoreMIDI"	# audio apps will want one or more of these
	);
	my @frameworks; 
	foreach( @sysframeworks ) {
		push( @frameworks, "/System/Library/Frameworks/$_.framework" );
	}
	
	my @resources;
		# any entries in this array will get added to the PBXResourcesBuildPhase; eventually this array,
		# like frameworks above, should probably get passed to this function.  Currently, we only use
		# an icon, and it will be added below if found to exist.
	my $icon = $hash{macosxicon};
	if( $icon ) {
		$icon = File::Spec->rel2abs( $icon );
		push @resources, $icon;
			# made absolute because we're going to be nested deeper in the xcode proj filea and will convert back
			# to relative later.
	}
	
	# undecided best way to handle: the xcode native project file is a level deeper
	# and we need to prepend an extra "../" to paths that are already relative paths...
	# So make everything absolute, then well pushCwd a level deeper, and later when emit
	# the files we convert back to relative.
	for( my $i=0; $i<scalar @files; $i++ ) {
		#if( $files[$i] =~ /^\.\./ ) {
			$files[$i] = File::Spec->rel2abs($files[$i]);
		#}
	}

	unlink( "zlab_xcode");
		# perhaps not necessary, to unlink; we might prefer to keep user prefs intact
	mkdir( "zlab_xcode" );
	mkdir( "zlab_xcode/zlab_xcode.xcodeproj");
	pushCwd( "zlab_xcode" );
		# this will affect the relative paths created later from paths that are currently absolute
	
	#
	# Write the info.plist file - somewhat equivalent to a windows resource file
	#
	open( PLIST, ">$name-Info.plist");
	print PLIST <<ENDOFPLIST;
	<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>CFBundleDevelopmentRegion</key>
		<string>English</string>
		<key>CFBundleExecutable</key>
		<string>\${EXECUTABLE_NAME}</string>
		<key>CFBundleIdentifier</key>
		<string>com.yourcompany.\${PRODUCT_NAME:rfc1034identifier}</string>
		<key>CFBundleInfoDictionaryVersion</key>
		<string>6.0</string>
		<key>CFBundlePackageType</key>
		<string>APPL</string>
		<key>CFBundleShortVersionString</key>
		<string>1.0</string>
		<key>CFBundleSignature</key>
		<string>????</string>
		<key>CFBundleVersion</key>
		<string>1</string>
		<key>LSMinimumSystemVersion</key>
		<string>\${MACOSX_DEPLOYMENT_TARGET}</string>
		<key>NSMainNibFile</key>
		<string>MainMenu</string>
		<key>NSPrincipalClass</key>
		<string>NSApplication</string>
ENDOFPLIST
	
	if( $icon ) {
		print PLIST "<key>CFBundleIconFile</key>\n";
		my( $volume, $directories, $filename ) = File::Spec->splitpath( $icon );
		print PLIST "<string>$filename</string>\n";
	}
	
	print PLIST <<ENDOFPLIST;
	</dict>
</plist>
ENDOFPLIST
	close PLIST;

	open( PBXPROJ, ">zlab_xcode.xcodeproj/project.pbxproj" );
	print PBXPROJ <<ENDOFPBXPROJ;
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 42;
	objects = {
ENDOFPBXPROJ



	#
	# PBXBuildFile section
	# @TODO: add the .a libs to this also -- currently these are emitted as additional linker flags
	#
	print PBXPROJ "/* Begin PBXBuildFile section */\n";
	my $buildType = "Sources";
	my( $fileRefID, $buildRefID );
	foreach( @files ) {
		if( $_ =~ /.+\.c/ || $_ =~ /.+\.cpp/ || $_ =~ /.+\.mm/ ) {
			( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
			my( $volume, $directories, $filename ) = File::Spec->splitpath( $_ );
			print PBXPROJ "\t\t$buildRefID /* $filename in $buildType */ = {isa = PBXBuildFile; fileRef = $fileRefID /* $filename */; };\n";;
		}
	}
	$buildType = "Frameworks";
	foreach( @frameworks ) {
		( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
		my( $volume, $directories, $filename ) = File::Spec->splitpath( $_ );
		print PBXPROJ "\t\t$buildRefID /* $filename in $buildType */ = {isa = PBXBuildFile; fileRef = $fileRefID /* $filename */; };\n";;
	}
	$buildType = "Resources";
	foreach( @resources ) {
		( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
		my( $volume, $directories, $filename ) = File::Spec->splitpath( $_ );
		print PBXPROJ "\t\t$buildRefID /* $filename in $buildType */ = {isa = PBXBuildFile; fileRef = $fileRefID /* $filename */; };\n";;
	}
	print PBXPROJ "/* End PBXBuildFile section */\n\n";


	#
	# DPBXFileReference section - all files referenced by the project, whether members of any build phase or not
	# You can choose to put all kind of things in here for handy access, like perl scripts, zui files, etc.
	#
	print PBXPROJ "/* Begin PBXFileReference section */\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "$name.app" );
	print PBXPROJ "\t\t$fileRefID /* $name.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = $name.app; sourceTree = BUILT_PRODUCTS_DIR; };\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "$name-Info.plist" );
	print PBXPROJ "\t\t$fileRefID /* $name-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = \"$name-Info.plist\"; sourceTree = \"<group>\"; };\n";
	if( $icon ) {
		( $fileRefID, $buildRefID ) = getXcodeGuid( $icon );
		my( $volume, $directories, $filename ) = File::Spec->splitpath( $icon );
		my $relPath = File::Spec->abs2rel( $icon );
		print PBXPROJ "\t\t$fileRefID /* $filename */ = {isa = PBXFileReference; lastKnownFileType = image.icns; path = \"$relPath\"; sourceTree = SOURCE_ROOT; };\n";
	}
	my $sourceType;
	my $sourceTree = "SOURCE_ROOT";
	foreach( @files ) {
		chomp;
		next if( $_ eq "" );
			# for some reason there is a "blank" file in the list.
		( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
		my $filePath = $_;
		if( File::Spec->file_name_is_absolute($_) ) {
			$filePath = File::Spec->abs2rel($_);
		}
		my( $volume, $directories, $filename ) = File::Spec->splitpath( $_ );
		if( $filename =~ /.+\.cpp/ ) {
			$sourceType = "sourcecode.cpp.cpp";
		}
		elsif( $filename =~ /.+\.mm/ ) {
			$sourceType = "sourcecode.cpp.objcpp";
		}
		elsif ( $filename =~ /.+\.h/ ) {
			$sourceType = "sourcecode.c.h";
		}
		elsif ( $filename =~ /.+\.pl/ ) {
			$sourceType = "text.script.perl";
		}
		else {
			$sourceType = "text";
		}
		print PBXPROJ "\t\t$fileRefID /* $filename */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = $sourceType; name = $filename; path = $filePath; sourceTree = $sourceTree; };\n";
	}
	
	$sourceTree = "\"<absolute>\"";
	$sourceType = "wrapper.framework";
	foreach( @frameworks ) {
		( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
		my( $volume, $directories, $filename ) = File::Spec->splitpath( $_ );
		print PBXPROJ "\t\t$fileRefID /* $filename */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = $sourceType; name = $filename; path = $_; sourceTree = $sourceTree; };\n";
	}
	print PBXPROJ "/* End PBXFileReference section */\n\n";
	
	#
	# PBXFrameworksBuildPhase section
	#
	print PBXPROJ "/* Begin PBXFrameworksBuildPhase section */\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Frameworks" );
	print PBXPROJ "\t\t$fileRefID /* Frameworks */ = {\n";
	print PBXPROJ "\t\t\tisa = PBXFrameworksBuildPhase;\n";
	print PBXPROJ "\t\t\tbuildActionMask = 2147483647;\n";
	print PBXPROJ "\t\t\tfiles = (\n";
	foreach( @frameworks ) {
		( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
		my( $volume, $directories, $filename ) = File::Spec->splitpath( $_ );
		print PBXPROJ "\t\t\t\t$buildRefID /* $filename in Frameworks */,\n";
	}
	print PBXPROJ "\t\t\t);\n";
	print PBXPROJ "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n";
	print PBXPROJ "\t\t};\n";
	print PBXPROJ "/* End PBXFrameworksBuildPhase section */\n\n";

	#
	# PBXGroup section
	#
	print PBXPROJ "/* Begin PBXGroup section */\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "PBXGroup" );
	print PBXPROJ "\t\t$fileRefID = {\n";
	print PBXPROJ "\t\t\tisa = PBXGroup;\n";
	print PBXPROJ "\t\t\tchildren = (\n";
	my @groups = ( "Products", "_plugin", "zbslib", "zlabcore", "frameworks" );
	foreach( @groups ) {
		( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
		print PBXPROJ "\t\t\t\t$fileRefID /* $_ */,\n";
	}
	print PBXPROJ "\t\t\t);\n";
	print PBXPROJ "\t\t\tsourceTree = \"<group>\";\n";
	print PBXPROJ "\t\t};\n";

	# each group from above will have a sublist of file references that should be placed
	# into that group - this is purely organizational for ease of navigation.  So we'll
	# split our files and frameworks into the appropriate groups.
	my %groupRefs;
	foreach( @groups ) {
		@{$groupRefs{ $_ }} = ();
	}
	foreach( @files ) {
		if( $_ =~ /.+zbslib.+/ ) {
			push @{$groupRefs{ 'zbslib' }}, $_;
		}
		elsif( $_ =~ /.+zlabcore.+/ ) {
			push @{$groupRefs{ 'zlabcore' }}, $_;
		}
		else {
			push @{$groupRefs{ '_plugin' }}, $_;
		}
	}
	foreach( @frameworks ) {
		push @{$groupRefs{ 'frameworks' }}, $_;
	}
	push @{$groupRefs{ '_plugin' }}, "$name-Info.plist";
	push @{$groupRefs{ 'Products' }}, "$name.app";
	if( $icon ) {
		push @{$groupRefs{ '_plugin' }}, $icon;
	}
	
	foreach( @groups ) {
		my $groupName = $_;
		( $fileRefID, $buildRefID ) = getXcodeGuid( $groupName );
		print PBXPROJ "\t\t$fileRefID /* $groupName */ = {\n";
		print PBXPROJ "\t\t\tisa = PBXGroup;\n";
		print PBXPROJ "\t\t\tchildren = (\n";
		foreach( @{$groupRefs{ $groupName }} ) {
			( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
			my( $volume, $directories, $filename ) = File::Spec->splitpath( $_ );
			print PBXPROJ "\t\t\t\t$fileRefID /* $filename */,\n";
		}
		print PBXPROJ "\t\t\t);\n";
		print PBXPROJ "\t\t\tname = $groupName;\n";
		print PBXPROJ "\t\t\tsourceTree = \"<group>\";\n";
		print PBXPROJ "\t\t};\n";
	}
	
	print PBXPROJ "/* End PBXGroup section */\n\n";
	
	#
	# PBXNativeTarget section
	#
	print PBXPROJ "/* Begin PBXNativeTarget section */\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( $name );
	print PBXPROJ "\t\t$fileRefID /* $name */ = {\n";
	print PBXPROJ "\t\t\tisa = PBXNativeTarget;\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "PBXNativeTarget-$name" );
	print PBXPROJ "\t\t\tbuildConfigurationList = $fileRefID /* Build configuration list for PBXNativeTarget \"$name\" */;\n";
	print PBXPROJ "\t\t\tbuildPhases = (\n";
	my @phases = ( "Resources", "Sources", "Frameworks" );
	foreach( @phases ) {
		( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
		print PBXPROJ "\t\t\t\t$fileRefID /* $_ */,\n";
	}
	print PBXPROJ "\t\t\t);\n";
	print PBXPROJ "\t\t\tbuildRules = (\n\t\t\t);\n";
	print PBXPROJ "\t\t\tdependencies = (\n\t\t\t);\n";
	print PBXPROJ "\t\t\tname = $name;\n";
	print PBXPROJ "\t\t\tproductName = $name;\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "$name.app" );
	print PBXPROJ "\t\t\tproductReference = $fileRefID /* $name.app */;\n";
	print PBXPROJ "\t\t\tproductType = \"com.apple.product-type.application\";\n";
	print PBXPROJ "\t\t};\n";
	print PBXPROJ "/* End PBXNativeTarget section */\n\n";

	#
	# PBXProject section
	#
	print PBXPROJ "/* Begin PBXProject section */\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "project object" );
	print PBXPROJ "\t\t$fileRefID /* Project object */ = {\n";
	print PBXPROJ "\t\t\tisa = PBXProject;\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "zlab_xcode" );
	print PBXPROJ "\t\t\tbuildConfigurationList = $fileRefID /* Build configuration list for PBXProject \"zlab_xcode\" */;\n";
	print PBXPROJ "\t\t\tcompatibilityVersion = \"Xcode 2.4\";\n";
	print PBXPROJ "\t\t\thasScannedForEncodings = 0;\n";
	
	( $fileRefID, $buildRefID ) = getXcodeGuid( "PBXGroup" );
	print PBXPROJ "\t\t\tmainGroup = $fileRefID;\n";
	
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Products" );
	print PBXPROJ "\t\t\tproductRefGroup = $fileRefID /* Products */;\n";
	print PBXPROJ "\t\t\tprojectDirPath = \"\";\n";
	print PBXPROJ "\t\t\tprojectRoot = \"\";\n";
	print PBXPROJ "\t\t\ttargets = (\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "$name" );
	print PBXPROJ "\t\t\t\t$fileRefID /* $name */,\n";
	print PBXPROJ "\t\t\t);\n";
	print PBXPROJ "\t\t};\n";
	print PBXPROJ "/* End PBXProject section */\n\n";
	
	#
	# PBXResourcesBuildPhase section : TODO? - the three build phases section could get factored into a single loop
	#
	print PBXPROJ "/* Begin PBXResourcesBuildPhase section */\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Resources" );
	print PBXPROJ "\t\t$fileRefID /* Resources */ = {\n";
	print PBXPROJ "\t\t\tisa = PBXResourcesBuildPhase;\n";
	print PBXPROJ "\t\t\tbuildActionMask = 2147483647;\n";
	print PBXPROJ "\t\t\tfiles = (\n";
	foreach( @resources ) {
		( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
		my( $volume, $directories, $filename ) = File::Spec->splitpath( $_ );
		print PBXPROJ "\t\t\t\t$buildRefID /* $filename in Resources */,\n";
	}
	print PBXPROJ "\t\t\t);\n";
	print PBXPROJ "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n";
	print PBXPROJ "\t\t};\n";
	print PBXPROJ "/* End PBXResourcesBuildPhase section */\n\n";

	#
	# PBXSourcesBuildPhase section
	#
	print PBXPROJ "/* Begin PBXSourcesBuildPhase section */\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Sources" );
	print PBXPROJ "\t\t$fileRefID /* Sources */ = {\n";
	print PBXPROJ "\t\t\tisa = PBXSourcesBuildPhase;\n";
	print PBXPROJ "\t\t\tbuildActionMask = 2147483647;\n";
	print PBXPROJ "\t\t\tfiles = (\n";
	foreach( @files ) {
		if( $_ =~ /.+\.c/ || $_ =~ /.+\.cpp/ || $_ =~ /.+\.mm/ ) {
			( $fileRefID, $buildRefID ) = getXcodeGuid( $_ );
			my( $volume, $directories, $filename ) = File::Spec->splitpath( $_ );
			print PBXPROJ "\t\t\t\t$buildRefID /* $filename in Sources */,\n";
		}
	}
	print PBXPROJ "\t\t\t);\n";
	print PBXPROJ "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n";
	print PBXPROJ "\t\t};\n";
	print PBXPROJ "/* End PBXSourcesBuildPhase section */\n\n";
	
	#
	# XCBuildConfiguration section
	#
	my $archSettings = "";
	if( $build64Bit ) {
		$archSettings = 'ARCHS = "$(ARCHS_STANDARD_64_BIT_PRE_XCODE_3_1)";
        ARCHS_STANDARD_64_BIT_PRE_XCODE_3_1 = x86_64;
        ';
	}
	print PBXPROJ "/* Begin XCBuildConfiguration section */\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Debug_zlab_xcode" );
	print PBXPROJ "\t\t$fileRefID /* Debug */ = {\n";
		# this is the debug configuration settings at the project level that apply to all targets
	print PBXPROJ <<BUILDCFG;
			isa = XCBuildConfiguration;
			buildSettings = {
				CLANG_CXX_LIBRARY = "libstdc++";
				COPY_PHASE_STRIP = NO;
				GCC_REUSE_STRINGS = NO;
				$archSettings
			};
			name = Debug;
		};
BUILDCFG
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Release_zlab_xcode" );
	print PBXPROJ "\t\t$fileRefID /* Release */ = {\n";
		# this is the Release configuration settings at the project level that apply to all targets
	print PBXPROJ <<BUILDCFG;
			isa = XCBuildConfiguration;
			buildSettings = {
				CLANG_CXX_LIBRARY = "libstdc++";
				COPY_PHASE_STRIP = YES;
				GCC_REUSE_STRINGS = NO;
				$archSettings
			};
			name = Release;
		};
BUILDCFG
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Debug_$name" );
	print PBXPROJ "\t\t$fileRefID /* Debug */ = {\n";
		# this is the debug configuration settings for the single target that this project contains
	print PBXPROJ <<BUILDCFG;
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_CXX_LIBRARY = "libstdc++";
				COPY_PHASE_STRIP = NO;
				GCC_REUSE_STRINGS = NO;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_ENABLE_FIX_AND_CONTINUE = YES;
				GCC_MODEL_TUNING = G5;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PRECOMPILE_PREFIX_HEADER = YES;
				GCC_PREFIX_HEADER = "";
				GCC_PREPROCESSOR_DEFINITIONS = (
					_DEBUG,
					__USE_GNU,
					_GNU_SOURCE,
BUILDCFG

	my $quotedDefines;
	foreach( uniquify( @{$hash{macosxdefines}} ) ) {
		if( /(.*)=\s*\"(.*)\"/ ) {
			$_ = "$1=\\\"\\\\\\\"$2\\\\\\\"\\\"";
				# "escapist" programming, by a true escape-artist.  tfb ;)
				$quotedDefines .= " " . $_;
				next;
		}
		print PBXPROJ "\t\t\t\t\t$_,\n";
	}
	if( $quotedDefines ne "" ) {
		print PBXPROJ "\t\t\t\t\t\"\$(GCC_PREPROCESSOR_DEFINITIONS_QUOTED_FOR_TARGET_1)\",\n";
		print PBXPROJ "\t\t\t\t);\n";
		print PBXPROJ "\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS_QUOTED_FOR_TARGET_1 = \"$quotedDefines\";\n";
	}
	else {
		print PBXPROJ "\t\t\t\t);\n";
	}

	print PBXPROJ "\t\t\t\tHEADER_SEARCH_PATHS = (\n";
	map{ $_ =~ s/^\.\.\//\.\.\/\.\.\//g; print PBXPROJ "\t\t\t\t\t$_,\n" } uniquify( @{$hash{includes}} );
	print PBXPROJ "\t\t\t\t);\n";
	
	print PBXPROJ "\t\t\t\tINFOPLIST_FILE = \"$name-Info.plist\";\n";
	print PBXPROJ "\t\t\t\tINSTALL_PATH = \"\$(HOME)/Applications\";\n";
	print PBXPROJ "\t\t\t\tOTHER_LDFLAGS = (\n";
	print PBXPROJ "\t\t\t\t\t-lpthread,\n";
	map{ print PBXPROJ "\t\t\t\t\t$_,\n" } uniquify( @{$hash{macosxlibs}} );
	print PBXPROJ "\t\t\t\t);\n";
	print PBXPROJ "\t\t\t\tPREBINDING = NO;\n";
	print PBXPROJ "\t\t\t\tPRODUCT_NAME = $name;\n";
	print PBXPROJ "\t\t\t};\n";
	print PBXPROJ "\t\t\tname = Debug;\n";
	print PBXPROJ "\t\t};\n";
	
# @TODO: much of what follows is just repeated for the Release, and could be factored; I leave it for now
# since it seems likely we'll want to differentiate defines etc. for debug vs release like we do in win32

	( $fileRefID, $buildRefID ) = getXcodeGuid( "Release_$name" );
	print PBXPROJ "\t\t$fileRefID /* Release */ = {\n";
		# this is the release configuration settings for the single target that this project contains
	print PBXPROJ <<BUILDCFG;
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				GCC_REUSE_STRINGS = NO;
				CLANG_CXX_LIBRARY = "libstdc++";
				COPY_PHASE_STRIP = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				GCC_ENABLE_FIX_AND_CONTINUE = NO;
				GCC_MODEL_TUNING = G5;
				GCC_PRECOMPILE_PREFIX_HEADER = YES;
				GCC_PREFIX_HEADER = "";
				GCC_PREPROCESSOR_DEFINITIONS = (
					__USE_GNU,
					_GNU_SOURCE,
BUILDCFG

	$quotedDefines = "";
	foreach( uniquify( @{$hash{macosxdefines}} ) ) {
		if( /(.*)=\s*\"(.*)\"/ ) {
			$_ = "$1=\\\"\\\\\\\"$2\\\\\\\"\\\"";
				# "escapist" programming, by a true escape-artist.  tfb ;)
				$quotedDefines .= " " . $_;
				next;
		}
		print PBXPROJ "\t\t\t\t\t$_,\n";
	}
	if( $quotedDefines ne "" ) {
		print PBXPROJ "\t\t\t\t\t\"\$(GCC_PREPROCESSOR_DEFINITIONS_QUOTED_FOR_TARGET_1)\",\n";
		print PBXPROJ "\t\t\t\t);\n";
		print PBXPROJ "\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS_QUOTED_FOR_TARGET_1 = \"$quotedDefines\";\n";
	}
	else {
		print PBXPROJ "\t\t\t\t);\n";
	}

	print PBXPROJ "\t\t\t\tHEADER_SEARCH_PATHS = (\n";
	map{ $_ =~ s/^\.\.\//\.\.\/\.\.\//g; print PBXPROJ "\t\t\t\t\t$_,\n" } uniquify( @{$hash{includes}} );
	print PBXPROJ "\t\t\t\t);\n";
	
	print PBXPROJ "\t\t\t\tINFOPLIST_FILE = \"$name-Info.plist\";\n";
	print PBXPROJ "\t\t\t\tINSTALL_PATH = \"\$(HOME)/Applications\";\n";
	print PBXPROJ "\t\t\t\tOTHER_LDFLAGS = (\n";
	print PBXPROJ "\t\t\t\t\t-lpthread,\n";
	map{ print PBXPROJ "\t\t\t\t\t$_,\n" } uniquify( @{$hash{macosxlibs}} );
	print PBXPROJ "\t\t\t\t);\n";
	print PBXPROJ "\t\t\t\tPREBINDING = NO;\n";
	print PBXPROJ "\t\t\t\tPRODUCT_NAME = $name;\n";
	print PBXPROJ "\t\t\t\tZERO_LINK = NO;\n";
	print PBXPROJ "\t\t\t};\n";
	print PBXPROJ "\t\t\tname = Release;\n";
	print PBXPROJ "\t\t};\n";
	print PBXPROJ "/* End XCBuildConfiguration section */\n";
	
	#
	# XCConfigurationList section
	#
	print PBXPROJ "/* Begin XCConfigurationList section */\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "zlab_xcode" );
	print PBXPROJ "\t\t$fileRefID /* Build configuration list for PBXProject \"zlab_xcode\" */ = {\n";
	print PBXPROJ "\t\t\tisa = XCConfigurationList;\n";
	print PBXPROJ "\t\t\tbuildConfigurations = (\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Debug_zlab_xcode" );
	print PBXPROJ "\t\t\t\t$fileRefID /* Debug */,\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Release_zlab_xcode" );
	print PBXPROJ "\t\t\t\t$fileRefID /* Release */,\n";
	print PBXPROJ <<ENDCFG;
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
ENDCFG
	( $fileRefID, $buildRefID ) = getXcodeGuid( "PBXNativeTarget-$name" );
	print PBXPROJ "\t\t$fileRefID /* Build configuration list for PBXNativeTarget \"$name\" */ = {\n";
	print PBXPROJ "\t\t\tisa = XCConfigurationList;\n";
	print PBXPROJ "\t\t\tbuildConfigurations = (\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Debug_$name" );
	print PBXPROJ "\t\t\t\t$fileRefID /* Debug */,\n";
	( $fileRefID, $buildRefID ) = getXcodeGuid( "Release_$name" );
	print PBXPROJ "\t\t\t\t$fileRefID /* Release */,\n";
	print PBXPROJ <<ENDCFG;
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
ENDCFG
	( $fileRefID, $buildRefID ) = getXcodeGuid( "project object");
	print PBXPROJ "\trootObject = $fileRefID /* Project object */;\n";
	print PBXPROJ "}\n\n";

	close( PBXPROJ );
	
	popCwd();
}

sub linux_runMakefile {
	my %hash = @_;
	executeCmd( "make -f $hash{linuxname} $hash{target}" );
}

sub macosx_runMakefile {
	my %hash = @_;
	executeCmd( "make -f $hash{macosxname} $hash{target}" );
}

sub win32_runMakefile {
	my %hash = @_;
	if( $devVersion == 18 ) {
		# visual studio 2013 is required to build 64bit windows zlab apps
		my $clean = $hash{target} eq 'clean' ? "/t:clean" : "";
		my $platform = platformBuild64Bit() ? "x64" : "win32";
		my $projname = platformBuild64Bit() ? $hash{win64name} : $hash{win64name};
			# um, vs2013 was originally used to just build win64, but even if we're building
			# a 32bit version, the name of the projectfile is the vcxproj format... 
		executeCmd( "msbuild $projname $clean /p:Platform=$platform /p:Configuration=\"$hash{win32config}\"" );
	}
	else {
		my $clean = $hash{target} eq 'clean' ? "/clean" : "";
		executeCmd( "vcbuild $hash{win32name} $clean \"$hash{win32config}\"" );
	}
}

####################################################################################################
#
# EXPERIMENTAL
#
####################################################################################################

use IO::Socket;

sub httpGet {
    my $url = shift;
	$url =~ m|http://([^/]+)(.*)|;

	my %returnHash;
	my $server = $1;
	my $dir = $2 ? $2 : "/";
    my $sock = new IO::Socket::INET( PeerAddr=>$server, PeerPort=>80, Proto=>'tcp' );

    if( ! $sock ) {
		$returnHash{Error} = "Unable to create socket $!";
		return %returnHash;
	}

	# SEND http request
    print $sock "GET $dir HTTP/1.0\n\n";

	my $replyCode = (split( /\s/, <$sock> ))[1];
	if( $replyCode != 200 ) {
		$returnHash{Error} = "HTTP Error $replyCode";
		return %returnHash;
	}

	# READ the header fields
	while( <$sock> ) {
		chomp;
		if( /^\s*$/ ) {
			# BEGIN body
			last;
		}
		else {
			/([^:]*):(.*)/;
			if( $1 ) {
				$returnHash{$1} = $2;
			}
		}
	}

	# READ the body lines
	while( <$sock> ) {
		$returnHash{Body} .= $_;
	}

	return %returnHash;
}

sub svnInfo {
	my $file = shift;
	my $svn = `svn info $file 2> nul`;
	my %hash;
	while( $svn =~ /([^:]*):\s*(.*)/g ) {
		my $key = $1;
		my $val = $2;
		$key =~ s/[\r\n]//g;
		$val =~ s/[\r\n]//g;
		$hash{$key} = $val;
	}
	return %hash;
}

sub experimentalSvnFetch {
	my %info = svnInfo( "main1.cpp" );
	print "Revision = " . $info{Revision};
	return;

	my @dirs = ( "zlab" );
	foreach my $dir( @dirs ) {
		my %httpResult = httpGet "http://svn.icmb.utexas.edu/svnrepos/$dir/";
		while( $httpResult{Body} =~ m|>(_[^</]*)(/)?</a>|g ) {
			my $name = $1;
			my $isDir = $2;
			if( $isDir ) {
				# A plugin subfolder, add it to the dir list
				push @dirs, "$dir/$1";
			}
			elsif( $name =~ /\.cpp/ ) {
				print "$name\n";
			}
		}
	}
}



