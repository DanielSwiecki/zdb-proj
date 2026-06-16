# Generuje plan JMeter jak w raporcie kolezanki:
# - dyskretne poziomy userow (25, 50, 75, ...)
# - TEN SAM czas trwania kazdego poziomu (HoldSec)
# - TEN SAM ramp-up (RampSec)
# - tylko liczba userow rosnie, czas staly

param(
    [int[]]$UserLevels = @(25, 50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500),
    [int]$HoldSec = 90,
    [int]$RampSec = 10,
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutputFile) {
    $OutputFile = Join-Path $root "benchmark-wyklad.jmx"
}

function New-TgBlock {
    param([int]$Users, [int]$HoldSec, [int]$RampSec)
    @"
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Poziom $Users uzytkownikow" enabled="true">
        <intProp name="ThreadGroup.num_threads">$Users</intProp>
        <intProp name="ThreadGroup.ramp_time">$RampSec</intProp>
        <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="Loop Controller">
          <intProp name="LoopController.loops">-1</intProp>
          <boolProp name="LoopController.continue_forever">false</boolProp>
        </elementProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">$HoldSec</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="$Users" enabled="true">
          <intProp name="HTTPSampler.connect_timeout">5000</intProp>
          <intProp name="HTTPSampler.response_timeout">30000</intProp>
          <stringProp name="HTTPSampler.domain">localhost</stringProp>
          <stringProp name="HTTPSampler.port">8081</stringProp>
          <stringProp name="HTTPSampler.protocol">http</stringProp>
          <stringProp name="HTTPSampler.path">/api/course-groups/`${groupId}/enroll</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.postBodyRaw">true</boolProp>
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments">
              <elementProp name="" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">{&quot;studentId&quot;: &quot;`${studentId}&quot;}</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
              </elementProp>
            </collectionProp>
          </elementProp>
        </HTTPSamplerProxy>
        <hashTree>
          <HeaderManager guiclass="HeaderPanel" testclass="HeaderManager" testname="Content-Type JSON" enabled="true">
            <collectionProp name="HeaderManager.headers">
              <elementProp name="" elementType="Header">
                <stringProp name="Header.name">Content-Type</stringProp>
                <stringProp name="Header.value">application/json</stringProp>
              </elementProp>
            </collectionProp>
          </HeaderManager>
          <hashTree/>
        </hashTree>
        <ConstantTimer guiclass="ConstantTimerGui" testclass="ConstantTimer" testname="Pauza 300ms" enabled="true">
          <stringProp name="ConstantTimer.delay">300</stringProp>
        </ConstantTimer>
        <hashTree/>
      </hashTree>
"@
}

$tgBlocks = ($UserLevels | ForEach-Object { New-TgBlock -Users $_ -HoldSec $HoldSec -RampSec $RampSec }) -join "`n"

$xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.6.3">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Benchmark wyklad - dyskretne poziomy">
      <boolProp name="TestPlan.serialize_threadgroups">true</boolProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
    </TestPlan>
    <hashTree>
      <CSVDataSet guiclass="TestBeanGUI" testclass="CSVDataSet" testname="CSV enrollments" enabled="true">
        <stringProp name="filename">enrollments.csv</stringProp>
        <stringProp name="fileEncoding">UTF-8</stringProp>
        <stringProp name="variableNames">studentId,groupId</stringProp>
        <stringProp name="delimiter">,</stringProp>
        <boolProp name="quotedData">false</boolProp>
        <boolProp name="recycle">false</boolProp>
        <boolProp name="stopThread">true</boolProp>
        <stringProp name="shareMode">shareMode.all</stringProp>
        <boolProp name="ignoreFirstLine">true</boolProp>
      </CSVDataSet>
      <hashTree/>
      <ResultCollector guiclass="SummaryReport" testclass="ResultCollector" testname="Summary Report" enabled="true">
        <boolProp name="ResultCollector.error_logging">false</boolProp>
        <objProp>
          <name>saveConfig</name>
          <value class="SampleSaveConfiguration">
            <time>true</time>
            <latency>true</latency>
            <timestamp>true</timestamp>
            <success>true</success>
            <label>true</label>
            <code>true</code>
            <message>true</message>
            <threadName>true</threadName>
            <dataType>true</dataType>
            <encoding>false</encoding>
            <assertions>true</assertions>
            <subresults>true</subresults>
            <responseData>false</responseData>
            <samplerData>false</samplerData>
            <xml>false</xml>
            <fieldNames>true</fieldNames>
            <responseHeaders>false</responseHeaders>
            <requestHeaders>false</requestHeaders>
            <responseDataOnError>false</responseDataOnError>
            <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
            <assertionsResultsToSave>0</assertionsResultsToSave>
            <bytes>true</bytes>
            <sentBytes>true</sentBytes>
            <threadCounts>true</threadCounts>
            <idleTime>true</idleTime>
            <connectTime>true</connectTime>
          </value>
        </objProp>
        <stringProp name="filename">wyniki_wyklad.jtl</stringProp>
      </ResultCollector>
      <hashTree/>
$tgBlocks
    </hashTree>
  </hashTree>
</jmeterTestPlan>
"@

[System.IO.File]::WriteAllText($OutputFile, $xml)
Write-Host "Plan JMeter: $OutputFile" -ForegroundColor Green
Write-Host "  Poziomy: $($UserLevels -join ', ')" -ForegroundColor Gray
Write-Host "  Kazdy poziom: ${HoldSec}s (ramp ${RampSec}s) - STALE" -ForegroundColor Gray
