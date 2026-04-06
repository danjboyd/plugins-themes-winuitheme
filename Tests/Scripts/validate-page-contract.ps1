param(
  [string]$Path = "$(Split-Path -Parent $PSScriptRoot)\..\Examples\Shared\PageContract\theme-demo-pages.json"
)

$resolved = Resolve-Path $Path -ErrorAction Stop
$contract = Get-Content $resolved -Raw | ConvertFrom-Json -ErrorAction Stop

if ($null -eq $contract.contractVersion -or [int]$contract.contractVersion -lt 1) {
  throw "Contract version must be 1 or greater."
}

if ($null -eq $contract.pages) {
  throw "Contract is missing pages."
}

$pageIds = @{}
foreach ($page in $contract.pages) {
  if ([string]::IsNullOrWhiteSpace($page.id)) {
    throw "Encountered a page without a stable id."
  }
  if ($pageIds.ContainsKey($page.id)) {
    throw "Duplicate page id '$($page.id)'."
  }
  $pageIds[$page.id] = $true

  if ($null -eq $page.sections) {
    throw "Page '$($page.id)' is missing sections."
  }

  $sectionIds = @{}
  foreach ($section in $page.sections) {
    if ([string]::IsNullOrWhiteSpace($section.id)) {
      throw "Page '$($page.id)' contains a section without a stable id."
    }
    if ($sectionIds.ContainsKey($section.id)) {
      throw "Duplicate section id '$($section.id)' on page '$($page.id)'."
    }
    $sectionIds[$section.id] = $true

    if ($null -eq $section.fixtures) {
      throw "Section '$($section.id)' on page '$($page.id)' is missing fixtures."
    }

    $fixtureIds = @{}
    foreach ($fixture in $section.fixtures) {
      if ([string]::IsNullOrWhiteSpace($fixture.id)) {
        throw "Section '$($section.id)' on page '$($page.id)' contains a fixture without a stable id."
      }
      if ([string]::IsNullOrWhiteSpace($fixture.kind)) {
        throw "Fixture '$($fixture.id)' on page '$($page.id)' section '$($section.id)' is missing a kind."
      }
      if ($fixtureIds.ContainsKey($fixture.id)) {
        throw "Duplicate fixture id '$($fixture.id)' in page '$($page.id)' section '$($section.id)'."
      }
      $fixtureIds[$fixture.id] = $true
    }
  }
}

Write-Output "Page contract validated: $resolved"
