# 2026 북중미 월드컵 뷰어 🏆

예선(조별리그 A~L)과 토너먼트(32강→결승)를 한 화면에서 보는 **단일 로컬 HTML** 앱.
조별리그는 종료된 결과(득점자·득점 시간 포함)를 보여주고, 토너먼트는 매일 **오전 7시·오후 1시**에 자동 갱신됩니다.

## 구성 파일
| 파일 | 설명 |
|---|---|
| `index.html` | UI 본체. 브라우저로 바로 열면 됨. 탭 2개(조별리그 / 토너먼트). |
| `data.js` | 데이터(`window.WC_DATA`). 업데이트 스크립트가 통째로 갱신. **2026-07-05 기준 실제 결과**가 들어 있음(웹 교차확인). |
| `config.local.json` | API 키 등 설정. **키를 직접 입력해야 함.** |
| `update-prompt.md` | `claude -p` 에 주는 데이터 갱신 지시문. |
| `run-update.ps1` | 작업 스케줄러가 호출하는 실행 래퍼. |
| `update.log` | 업데이트 실행 로그(자동 생성). |

## 바로 보기
`index.html` 을 더블클릭하거나 브라우저로 열면 됩니다. (별도 서버 불필요 — 데이터를 `data.js`로 로드하므로 `file://` 에서도 동작)

---

## 설정 (최초 1회)

### 1) API 키 발급 (무료)
1. https://www.api-football.com/ 가입 → 대시보드에서 **API Key** 확인 (무료 플랜: 하루 100요청).
2. `config.local.json` 을 열어 `apiKey` 값에 붙여넣기:
```json
{ "apiKey": "발급받은키", "league": 1, "season": 2026, "apiBase": "https://v3.football.api-sports.io" }
```
> ⚠️ `config.local.json` 에는 개인 키가 들어가니 외부에 공유/커밋하지 마세요.

### 2) 첫 데이터 채우기 (수동 1회)
샘플을 실제 결과로 바꾸려면 한 번 수동 실행:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\projects\jb_31\run-update.ps1"
```
끝나면 `data.js` 가 실데이터로 바뀌고 `update.log` 에 결과가 남습니다. 브라우저 새로고침으로 확인.
> 조별리그 72경기 이벤트까지 처음에 받으면 요청 수가 많습니다(≈85). 하루 한도(100)에 걸리면 다음 실행에서 이어서 채웁니다.

---

## 자동 갱신 등록 (매일 07:00 / 13:00)

PowerShell을 **관리자로 실행할 필요 없이**(내 계정 작업으로) 아래를 한 번 실행:

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
- **"데이터 준비 중"만 보임** → `data.js` 가 없거나 비었음. 업데이트 1회 실행.
- **한글 대신 영문 팀명** → 매핑 테이블(`update-prompt.md`)에 없는 팀. 필요하면 매핑 추가.
- **득점자 공란** → 무료 플랜의 이벤트 커버리지 지연일 수 있음. 스코어는 정상 표시됨.
- **요청 한도 초과** → 다음 실행에서 미처리분을 이어서 처리. `update.log` 참고.
# jb_31
