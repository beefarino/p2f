#
# Copyright (c) 2014 Code Owls LLC
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
# 	psake build script for the P2F library
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
		'./src/ProviderFramework.sln'
	);	
	$libPath = "./lib"
    $targetPath = "./src/P2F/CodeOwls.PowerShell.Provider/bin";
    $metadataAssembly = 'CodeOwls.PowerShell.Provider.dll'
};

framework '4.0'

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

task default -depends Build;

$private = "this is a private task not meant for external use";

# private tasks 
task __VerifyConfiguration -description $private {
	Assert ( @('Debug', 'Release') -contains $config ) "Unknown configuration, $config; expecting 'Debug' or 'Release'";
	Assert ( Test-Path $slnFile ) "Cannot find solution, $slnFile";
	
	Write-Verbose ("packageDirectory: " + ( get-packageDirectory ));
}

task __CreatePackageDirectory -description $private {
	get-packageDirectory | create-packageDirectory;		
}

task __CreateNuGetPackageDirectory -description $private {
    $p = get-nugetPackageDirectory;
    $p  | create-packageDirectory;
    @( 'tools','lib','content' ) | %{join-path $p -child $_ } | create-packageDirectory;
}

task __CreateLocalDataDirectory -description $private {
	if( -not ( Test-Path $local ) )
	{
		mkdir $local | Out-Null;
	}
}

# primary targets

task Build -depends __VerifyConfiguration -description "builds any outdated dependencies from source" {
	exec { 
		msbuild $slnFile /p:Configuration=$config /p:KeyContainerName=$keyContainer /t:Build 
	}
}

task Clean -depends __VerifyConfiguration,CleanNuGet -description "deletes all temporary build artifacts" {
	exec { 
		msbuild $slnFile /p:Configuration=$config /t:Clean 
	}
}

task Rebuild -depends Clean,Build -description "runs a clean build";

task Package -depends Build -description "assembles distributions in the source hive" {

}

# clean tasks

task CleanNuGet -depends __CreateNuGetPackageDirectory -description "clears the nuget package staging area" {
    get-nugetPackageDirectory | 
        ls | 
        ?{ $_.psiscontainer } | 
        ls | 
        remove-item -recurse -force;
}




