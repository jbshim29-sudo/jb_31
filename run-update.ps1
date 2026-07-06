# run-update.ps1
# Windows 작업 스케줄러가 매일 07:00 / 13:00 에 호출하는 래퍼.
# update-prompt.md 를 claude -p(비대화형)로 실행해 data.js 를 갱신하고 update.log 에 기록한다.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$log = Join-Path $root "update.log"
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $log -Value "`n===== $stamp 업데이트 시작 ====="

# claude 실행 파일 확인
$claude = (Get-Command claude -ErrorAction SilentlyContinue)
if (-not $claude) {
  Add-Content -Path $log -Value "[오류] claude CLI 를 찾을 수 없습니다. PATH 확인 필요."
  exit 1
}

$prompt = Get-Content (Join-Path $root "update-prompt.md") -Raw -Encoding UTF8

# 비대화형 실행: 스케줄러 환경이라 권한 프롬프트가 뜨면 멈추므로 자동 승인.
# (웹 검색으로 결과를 확인하고 data.js 만 갱신하도록 update-prompt.md 로 제한되어 있음)
try {
  $out = $prompt | & claude -p `
      --dangerously-skip-permissions `
      --allowedTools "Bash,Read,Write,Edit,WebSearch,WebFetch" 2>&1 | Out-String
  Add-Content -Path $log -Value $out
  Add-Content -Path $log -Value "[완료] $(Get-Date -Format 'HH:mm:ss')"
} catch {
  Add-Content -Path $log -Value "[예외] $($_.Exception.Message)"
  exit 1
}
