#
# Copyright (c) 2012 Code Owls LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy 
# of this software and associated documentation files (the "Software"), to 
# deal in the Software without restriction, including without limitation the 
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
# sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
# IN THE SOFTWARE. 
# 
# 	psake build script for the SQLite provider and module
#
# 	valid configurations:
#  		Debug
#  		Release
#
# notes:
#

properties {
	$config = 'Debug'; 	
	$local = './_local';
	$keyContainer = '';
	$slnFile = @(
		'./src/SQLiteProvider.sln'
	);	
	$libPath = "./lib"
    $targetPath = "./src/CodeOwls.PowerShell.SQLite.Provider/bin";
	$moduleSource = "./src/Modules";
    $metadataAssembly = 'CodeOwls.PowerShell.SQLite.Provider.dll'
};

$framework = '4.0'

function get-packageDirectory
{
	return "." | resolve-path | join-path -child "/bin/$config";
}

function get-nugetPackageDirectory
{
    return "." | resolve-path | join-path -child "/bin/$config/NuGet";
}

function get-modulePackageDirectory
{
    return "." | resolve-path | join-path -child "/bin/$config/Modules";
}

function get-zipPackageName
{
	"SQLite.$(get-ProviderVersion).zip"
}

function create-PackageDirectory( [Parameter(ValueFromPipeline=$true)]$packageDirectory )
{
    process
    {
        write-verbose "checking for package path $packageDirectory ..."
        if( !(Test-Path $packageDirectory ) )
    	{
    		Write-Verbose "creating package directory at $packageDirectory ...";
    		mkdir $packageDirectory | Out-Null;
    	}
    }    
}

function get-ProviderVersion
{
	$p = get-modulePackageDirectory;    
    $md = join-path $p "SQLite\bin\$metadataAssembly";
	Write-Verbose "reading metadata from assembly at path $md";
    ( get-item $md | select -exp versioninfo | select -exp productversion );
}

task default -depends Install;

. ./psake/commontask.ps1

# test tasks

task Test -depends Build,Package,Install,__CreateLocalDataDirectory -description "executes functional tests" {
	Write-Verbose "running tests ...";
	
	# we run tests in a nested powershell session so binary modules will be unloaded from memory
	# 	after the tests are complete.
	#	this will allow us to rerun the build from the same console.
	$xmlfile =  './_local/localtests.xml';
	
	powershell -outputformat XML -command "cd ./tests | out-null; ./invoke-tests.ps1 -erroraction 'silentlycontinue' -warningaction 'silentlycontinue'  " | Export-Clixml $xmlfile -Force;
	$results = Import-Clixml $xmlfile;
	
	#drop the results to the console output
	$results;	
	
	$failures = $results | where { -not $_.result };
	if( $failures )
	{	
		throw "one or more tests have failed"
	}
}

# package tasks

task PackageModule -depends CleanModule,Build,__CreateModulePackageDirectory -description "assembles module distribution file hive" -action {
	$mp = get-modulePackageDirectory;
	
	# copy module src hive to distribution hive
	Copy-Item $moduleSource -container -recurse -Destination $mp -Force;
	
	# copy bins to module bin area
	mkdir "$mp\SQLite\bin" | Out-Null;
	ls "$targetPath/$config" | copy-item -dest "$mp\SQLite\bin" -recurse -force;
	
	# copy sqlite dlls to module bin area
	# 	note there are two flavors: x32 and x64; we keep them in unique subfolders and only
	#	load the one we need at runtime
	ls $libPath -Filter x* | Copy-Item -Destination "$mp\SQLite\bin" -Container -Recurse -Force;
} 

task PackageZip -depends PackageModule -description "assembles zip archive of module distribution" -action {
	$mp = get-modulePackageDirectory | Get-Item;
	$pp = get-packageDirectory;
	$zp = get-zipPackageName ;
	
	Import-Module pscx;
	
	Write-Verbose "module package path: $mp";
	Write-Verbose "package path: $pp";
	Write-Verbose "zip package name: $zp";
	
	write-zip -path "$mp\SQLite" -outputpath $zp | Move-Item -Destination $pp -Force ;	
}

# install tasks

task Uninstall -description "uninstalls the module from the local user module repository" {
	$modulePath = $Env:PSModulePath -split ';' | select -First 1 | Join-Path -ChildPath 'SQLite';
	if( Test-Path $modulePath )
	{
		Write-Verbose "uninstalling module from local module repository at $modulePath";
		
		$modulePath | ri -Recurse -force;
	}
}

task Install -depends InstallModule -description "installs the module to the local machine";

task InstallModule -depends PackageModule -description "installs the module to the local user module repository" {
	$packagePath = get-modulePackageDirectory;
	$modulePath = $Env:PSModulePath -split ';' | select -First 1;
	Write-Verbose "installing module from local module repository at $modulePath";
	
	ls $packagePath | Copy-Item -recurse -Destination $modulePath -Force;	
}

