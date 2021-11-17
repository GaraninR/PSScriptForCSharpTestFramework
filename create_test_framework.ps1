dotnet new sln

New-Item src -ItemType Directory
New-Item tests -ItemType Directory

$CurProjName = Split-Path -Path (Get-Location) -Leaf

New-Item ./src/$CurProjName -ItemType Directory
New-Item ./tests/$CurProjName.Tests -ItemType Directory


dotnet new console --name "$CurProjName" --output ./src/$CurProjName
dotnet new nunit --name "$CurProjName.Tests" --output ./tests/$CurProjName.Tests

dotnet sln add --in-root "./src/$CurProjName/$CurProjName.csproj"
dotnet sln add --in-root "./tests/$CurProjName.Tests/$CurProjName.Tests.csproj"

dotnet add "./tests/$CurProjName.Tests/$CurProjName.Tests.csproj" reference "./src/$CurProjName/$CurProjName.csproj"
dotnet new gitignore

Set-Location -Path ./tests/$CurProjName.Tests
dotnet add package Selenium.WebDriver
dotnet add package Microsoft.Edge.SeleniumTools
dotnet add package Selenium.Firefox.WebDriver
dotnet add package Selenium.Chrome.WebDriver
dotnet add package Microsoft.Extensions.Configuration
dotnet add package Microsoft.Extensions.Configuration.Json
dotnet add package log4net

New-Item ./Tests -ItemType Directory
Rename-Item -Path "UnitTest1.cs" -NewName "DefaultTest.cs"
Move-Item "DefaultTest.cs" ./Tests 

$configTemplate = '
{
    "testAutomationConfig":
    {
        "baseUrl": "http://zerkalo.io",
        "browser": "edge",
        "selenoid": "false",
        "selenoidPrefs": {
            "selenoidUrl": "http://localhost:4444/wd/hub/"
        }
    }   
}'


$configTemplate | Out-File -Path "./config.json"

$allureConfigTemplate = '
{
	"allure": {
		"directory": "../../../../../allure-results",
		"links": [
			"https://github.com/nunit/docs/issues?utf8=✓&q={issue}",
			"https://example.org/{tms}",
			"{link}"
		],
		"brokenTestData": [
			"System.Exception"
		]
	}
}'

$allureConfigTemplate | Out-File -Path "./allureConfig.json"

Set-Location -Path ../..

$DriversDir = "./tests/$CurProjName.Tests/Drivers"

New-Item $DriversDir -ItemType Directory

# Archive name is depend on platform
$chromeArchiveName = 'chromedriver_linux64.zip'
$firefoxArchiveName = 'geckodriver-v0.29.1-linux64.tar.gz'
$edgeArchiveName = 'edgedriver_linux64.zip'

# Get Drivers
If ($IsLinux) {
	Write-Host "It's Linux!"	
}
ElseIf ($IsWindows) {
	Write-Host "It's Windows!"
	
    $chromeArchiveName = 'chromedriver_win32.zip'
    $firefoxArchiveName = 'geckodriver-v0.29.1-win64.zip'
    $edgeArchiveName = 'edgedriver_win64.zip'

}
Else {
	Write-Host "Unsupported OS!"
    Write-Host "We will download drivers for Linux"
	Write-Host "Download drivers manually for your system. Put them in 'Drivers' directory"
}

#Chromedriver for Google Chrome
Invoke-WebRequest https://chromedriver.storage.googleapis.com/92.0.4515.43/$chromeArchiveName -OutFile $chromeArchiveName
Expand-Archive -path $chromeArchiveName -destinationpath $DriversDir
Remove-Item $chromeArchiveName

#Geckodriver for Firefox
Invoke-WebRequest https://github.com/mozilla/geckodriver/releases/download/v0.29.1/$firefoxArchiveName -OutFile $firefoxArchiveName
If ($IsLinux) {
	tar -xvzf $firefoxArchiveName -C $DriversDir
}
Else {
    Expand-Archive -path $firefoxArchiveName -destinationpath $DriversDir
}

Remove-Item $firefoxArchiveName

#EDGEDriver for MS Edge
Invoke-WebRequest https://msedgedriver.azureedge.net/92.0.902.49/$edgeArchiveName -OutFile $edgeArchiveName
Expand-Archive -path $edgeArchiveName -destinationpath $DriversDir
Remove-Item $edgeArchiveName

If ($IsLinux) {	
    chmod 777 -R $DriverDir
}

New-Item ./tests/$CurProjName.Tests/PageObjects -ItemType Directory
New-Item ./tests/$CurProjName.Tests/TestFramework -ItemType Directory
New-Item ./tests/$CurProjName.Tests/TestFramework/Models -ItemType Directory


dotnet restore
dotnet build
dotnet test

## GENERATE TEST FRAMEWORK FILES

# generate Config.cs

$ConfigCSCSharpFileText = "
using OpenQA.Selenium;
using OpenQA.Selenium.Firefox;
using OpenQA.Selenium.Chrome;
using Microsoft.Extensions.Configuration;
using Microsoft.Edge.SeleniumTools;
using System;
using OpenQA.Selenium.Remote;

namespace TestFramework
{
    public class Config
    {
        
        IConfigurationRoot configuration;
        string configFile;


        public IWebDriver getDriver() {

            
            if (isSelenoid() == `"true`") {

                var capabilities = new DesiredCapabilities();
                if (getVNCPrefs()) capabilities.SetCapability(`"enableVNC`", true);

                switch (getBrowserType()) 
                {
                    case `"chrome`":                        
                        capabilities.SetCapability(CapabilityType.BrowserName, `"chrome`");                       
                        break;
                    case `"firefox`":
                        capabilities.SetCapability(CapabilityType.BrowserName, `"firefox`");
                        break;
                    case `"opera`":
                        capabilities.SetCapability(CapabilityType.BrowserName, `"opera`");
                        break;
                    default:
                        throw new Exception(`"Unknown browser type for Selenoid!`");                    
                }
                return new RemoteWebDriver(new Uri(getRemoteDriverUrl()), capabilities);
            }
            else
            {
                switch (getBrowserType())
                {
                    case `"edge`":
                        var options = new EdgeOptions();
                        options.UseChromium = true;
                        return new EdgeDriver(getDriverPath(), options);
                    case `"firefox`":
                        return new FirefoxDriver(getDriverPath());
                    case `"chrome`":
                        return new ChromeDriver(getDriverPath());
                    default:
                        throw new Exception(`"Unknown browser type!`");
                }
            }
                        
        }

        public string getBaseUrl() {

            return configuration[`"testAutomationConfig:baseUrl`"];
        }

        private string getDriverPath() {
            return `"./Drivers`";
        }

        private bool getVNCPrefs() {
            return configuration[`"testAutomationConfig:baseUrl`"] == `"true`" ? true : false;
        }

        private string getRemoteDriverUrl() {
            return configuration[`"testAutomationConfig:selenoidPrefs:selenoidUrl`"];
        }

        private string getBrowserType() {
            
            return configuration[`"testAutomationConfig:browser`"];
        }

        private string isSelenoid() {
            
            return configuration[`"testAutomationConfig:selenoid`"];
        }

        public Config() {
                configFile = `"config.json`";

                try
                {
                    configuration = new ConfigurationBuilder()
                    .AddJsonFile(configFile, optional: true)
                    .Build();
                }
                catch (System.Exception)
                {
                    throw;
                }
                
        }
    }
}
"

$ConfigCSCSharpFileText | Out-File -Path ./tests/$CurProjName.Tests/TestFramework/Config.cs

# generate BaseTest.cs

$BaseTestCSCSharpFile = "
using log4net;
using NUnit.Framework;
using OpenQA.Selenium;
using TestFramework;

namespace Tests
{
    public class BaseTest
    {
        protected IWebDriver driver;
        protected ILog Logger;
        protected Config conf;

        [SetUp]
        public virtual void init()
        {
            this.conf = new Config();
            this.driver = conf.getDriver();
            this.Logger = LogManager.GetLogger(GetType());
            this.Logger.Info(`"log4net initialized`");
            this.driver.Manage().Window.Maximize();
            this.Logger.Info(`"Test started`");

        }

        [TearDown]
        public virtual void cleanup()
        {
            this.driver.Quit();
        }
    }
}
"

$BaseTestCSCSharpFile | Out-File -Path ./tests/$CurProjName.Tests/Tests/BaseTest.cs

# generate FirstTest.cs
$FirstTestCSCSharpFile = "
using NUnit.Framework;
using System.Threading;
using Tests;

namespace `Tests
{
    public class Tests : BaseTest
    {

        [Test]
        public void Test1()
        {
            driver.Url = conf.getBaseUrl();
            Thread.Sleep(2000);
        }

    }
}
"

$FirstTestCSCSharpFile | Out-File -Path ./tests/$CurProjName.Tests/Tests/FirstTest.cs

# generate Jenkinsfile
$JenkinsfileFile = "
node {
    git 'http://gitlab.local/user/testautomationrepo.git'
    
    stage('Build test automation solution')
    
    sh 'dotnet build'
    
    stage('Run tests')
    
    sh 'dotnet test'
    
    stage('Generate Allure Report') {
            allure([
                    includeProperties: false,
                    jdk: '',
                    properties: [],
                    reportBuildPolicy: 'ALWAYS',
                    results: [[path: 'allure-results']]
            ])
    }
}
"

$JenkinsfileFile | Out-File -Path ./Jenkinsfile

# generate Jenkinsfile
$GitLabCIYMLFile = "
stages:
  - build
  - test

build-test-framework:
  stage: build
  script:
    - dotnet build

build-test-framework:
  stage: test
  script:
    - dotnet test
"

$GitLabCIYMLFile | Out-File -Path ./.gitlab-ci.yml

git init
git add .
git commit -m "Initial commit"






