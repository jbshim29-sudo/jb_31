# 2026 북중미 월드컵 뷰어 🏆

예선(조별리그 A~L)과 토너먼트(32강→결승)를 한 화면에서 보는 **단일 로컬 HTML** 앱.
조별리그는 종료된 결과(득점자·득점 시간 포함)를 보여주고, 토너먼트는 매일 **오전 7시·오후 1시**에 자동 갱신됩니다.
데이터는 **웹 검색으로 수집**하므로 API 키·가입이 필요 없습니다.

## 구성 파일
| 파일 | 설명 |
|---|---|
| `index.html` | UI 본체. 브라우저로 바로 열면 됨. 탭 2개(조별리그 / 토너먼트). |
| `data.js` | 데이터(`window.WC_DATA`). 업데이트 스크립트가 갱신. 실제 결과가 들어 있음(웹 교차확인). |
| `update-prompt.md` | `claude -p` 에 주는 데이터 갱신 지시문(웹 검색으로 녹아웃 결과 확인). |
| `run-update.ps1` | 작업 스케줄러가 호출하는 실행 래퍼. |
| `update.log` | 업데이트 실행 로그(자동 생성). |
| `config.local.json` | (미사용) 과거 API 방식의 잔재. 웹 기반으로 바뀌어 필요 없음. |

## 바로 보기
`index.html` 을 더블클릭하거나 브라우저로 열면 됩니다. (별도 서버 불필요 — 데이터를 `data.js`로 로드하므로 `file://` 에서도 동작)

## 동작 방식
`run-update.ps1` → `claude -p`(비대화형) → **웹 검색(위키피디아·ESPN·FIFA·네이버 스포츠 등)**으로 최신 녹아웃 결과 확인 → `data.js` 의 토너먼트 부분만 갱신. 조별리그와 이미 확정된 경기는 건드리지 않고, 아직 안 열린 경기는 그대로 둡니다(없는 결과·득점자를 지어내지 않음). ⚠️ 로컬에서 `claude` CLI 가 로그인되어 있어야 동작합니다.

---

## 수동 실행 (원할 때 즉시 갱신)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\projects\jb_31\run-update.ps1"
```
끝나면 `data.js` 가 갱신되고 `update.log` 에 결과가 남습니다. 브라우저 새로고침으로 확인.

---

## 자동 갱신 (매일 07:00 / 13:00)

✅ **이미 등록되어 있습니다** (작업 이름: `WorldCup2026Update`). PC가 켜져 로그인된 상태면 매일 07:00·13:00에 자동 실행됩니다. 상태 확인: `Get-ScheduledTaskInfo -TaskName WorldCup2026Update`.

재등록이 필요할 때만 아래를 실행하세요:

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
             -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\projects\jb_31\run-update.ps1"'
$t1 = New-ScheduledTaskTrigger -Daily -At 7:00am
$t2 = New-ScheduledTaskTrigger -Daily -At 1:00pm
$set = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName "WorldCup2026Update" -Action $action -Trigger $t1,$t2 `
             -Settings $set -Description "2026 월드컵 data.js 자동 갱신 (07:00/13:00)"
```
- `-StartWhenAvailable`: PC가 그 시각에 꺼져 있었으면 켜진 직후 놓친 작업을 실행.
- PC가 켜져 로그인된 상태에서 동작합니다(세션 유지는 불필요).

### 지금 바로 한 번 테스트 실행
```powershell
Start-ScheduledTask -TaskName "WorldCup2026Update"
# 잠시 후 로그 확인
Get-Content "C:\projects\jb_31\update.log" -Tail 20
```

### 대회 종료(7/19) 후 정리
```powershell
Unregister-ScheduledTask -TaskName "WorldCup2026Update" -Confirm:$false
```

---

## 데이터 스키마 (`data.js`)
```js
window.WC_DATA = {
  updatedAt: "2026-07-05T13:00:00+09:00",
  groups: [ { name:"A",
    standings:[ {rank,team,played,won,drawn,lost,gf,ga,gd,points} ],   // 4팀
    matches:[ {date,home,away,homeScore,awayScore,status,
               goals:[ {minute,player,side:"home|away",type:"goal|penalty|own"} ]} ] } ],  // A~L
  knockout: {
    r32:[ {id,date,home,away,homeScore,awayScore,status,winner,detail,goals:[...]} ],  // 16 (앞8=좌,뒤8=우)
    r16:[...8], qf:[...4], sf:[...2],
    final:{ ...단일 객체 }
  }
}
```
- `status`: `NS`(예정) / `LIVE` / `FT`(종료) / `TBD`(대진 미정)
- 미정 대진은 `home:"미정", away:"미정", status:"TBD"` 로 자리 유지(사다리꼴 레이아웃 보존)

## 트러블슈팅
- **업데이트가 안 됨** → ① 예약 작업 존재 확인(`Get-ScheduledTaskInfo -TaskName WorldCup2026Update`), ② `claude` CLI 로그인 여부, ③ `update.log` 마지막 줄 확인. 수동 실행으로 즉시 원인 파악 가능.
- **"데이터 준비 중"만 보임** → `data.js` 가 없거나 비었음. 수동 실행 1회.
- **득점자 공란** → 웹에서 득점자가 확인 안 된 경기. 스코어는 정상 표시됨(지어내지 않음).
- **새 결과 반영이 느림** → 경기 종료 후 소스 반영까지 시간차. 다음 실행(7시/13시)에 채워짐.
