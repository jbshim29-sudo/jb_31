# 월드컵 데이터 업데이트 지시문 (claude -p 용)

너는 이 프로젝트 폴더에서 실행되는 비대화형 에이전트다. 아래 절차대로 **API-Football(api-sports.io)** 에서 2026 북중미 월드컵 데이터를 가져와 `data.js` 파일을 갱신하라. 사람에게 질문하지 말고, 불필요한 설명 없이 작업만 수행한 뒤 마지막에 한 줄 요약(갱신 경기 수 / 사용한 API 요청 수)만 출력하라.

## 0. 준비
- 작업 폴더: 현재 디렉터리(`index.html`, `data.js`, `config.local.json` 가 있는 곳).
- `config.local.json` 을 읽어 `apiKey`, `league`(=1), `season`(=2026), `apiBase` 를 얻는다.
- `apiKey` 가 비어 있거나 placeholder(`여기에_`로 시작)면 **아무것도 덮어쓰지 말고** "API 키가 설정되지 않았습니다"만 출력하고 종료.
- 현재 시각은 Bash `date` 명령으로 구한다(ISO8601 + KST 오프셋).

## 1. 기존 data.js 로드 (레이트리밋 절약)
- 기존 `data.js` 가 있으면 읽어서, 이미 `status:"FT"` 이고 `goals` 배열이 채워진 경기의 fixture `id` 목록을 확보한다.
- 이 경기들은 **이벤트(득점)를 다시 요청하지 않는다.** 새로 끝났거나 진행 중(LIVE)인 경기만 이벤트를 요청한다.
- 단, 기존 파일이 `sample:true` 이면 전체를 새로 구축한다(샘플이므로).

## 2. API 호출 (모든 요청 헤더: `x-apisports-key: <apiKey>`)
`curl -s -H "x-apisports-key: KEY" "URL"` 형식. base = `apiBase`.

1. **순위/조 구성**: `GET /standings?league=1&season=2026`
   - 응답 `response[0].league.standings` 는 조별 배열. 각 조에서 팀명·경기수·승·무·패·득점·실점·득실차·승점·순위를 추출.
   - 조 이름(A~L)은 `group` 필드에서 "Group A" → "A" 로 정리.
   - **팀 → 조 매핑 테이블**을 만들어 둔다(다음 단계에서 경기를 조에 배정할 때 사용).

2. **전체 일정/스코어**: `GET /fixtures?league=1&season=2026`
   - 각 fixture 에서: `fixture.id`, `fixture.date`, `fixture.status.short`(NS/1H/HT/2H/FT/AET/PEN 등), `teams.home/away.name`, `goals.home/away`, `score.penalty`(승부차기), `league.round`(예: "Group Stage - 1", "Round of 32", "Round of 16", "Quarter-finals", "Semi-finals", "Final") 추출.
   - status 매핑: `NS`→미시작, `1H/2H/HT/ET/LIVE`→LIVE, `FT/AET/PEN`→FT, 미정 대진→TBD.

3. **득점 이벤트**(1단계 필터 통과한 경기만): `GET /fixtures/events?fixture=ID`
   - `type=="Goal"` 인 이벤트만 사용. `time.elapsed`(+`time.extra` 있으면 `"45+2"` 형태로), `player.name`, 팀이 홈이면 `side:"home"` 아니면 `"away"`.
   - `detail=="Penalty"`→`type:"penalty"`, `detail=="Own Goal"`→`type:"own"`, 그 외 `type:"goal"`.
   - **요청 총합이 90건을 넘지 않도록** 관리한다(무료 100/일). 남은 미처리 경기가 있으면 다음 실행 때 이어서 처리하고, 로그에 남긴다.

## 3. 데이터 조립 → 아래 스키마로 `window.WC_DATA` 구성
```js
window.WC_DATA = {
  updatedAt: "<ISO8601+09:00>",
  groups: [ { name:"A",
    standings:[{rank,team,played,won,drawn,lost,gf,ga,gd,points}, ...4팀],
    matches:[{date:"MM-DD",home,away,homeScore,awayScore,status,goals:[{minute,player,side,type}]}] } ...A~L ],
  knockout: {
    r32:[ {id,date:"MM-DD",home,away,homeScore,awayScore,status,winner,detail,goals:[...]} ...16 ],
    r16:[...8], qf:[...4], sf:[...2], final:{...1}
  }
}
```
규칙:
- **조 배정**: 각 group-stage fixture 를 홈팀의 조(1단계 매핑)로 넣는다. 각 조 matches 는 날짜순 정렬.
- **녹아웃 배열 크기 고정**: r32=16, r16=8, qf=4, sf=2, final=1. 아직 대진이 안 정해진 자리는 `home:"미정", away:"미정", status:"TBD"` placeholder 로 채워 크기를 유지한다(뷰의 사다리꼴 레이아웃이 깨지지 않도록).
- **좌우 배치**: r32 앞 8경기 = 왼쪽, 뒤 8경기 = 오른쪽으로 뷰가 나누므로, 대진표 상단→하단 순서를 유지해 넣는다(API의 fixture 순서 사용).
- **winner**: FT 인 경기만 설정. 정규/연장 스코어로 판정, 동점이면 `score.penalty` 로 승자 결정하고 `detail:"승부차기 X-Y"` 표기. 연장 승부면 `detail:"연장 승부"`.
- **final** 은 배열이 아니라 단일 객체.

## 4. 팀명 한글 표기
아래 매핑을 적용하고, 표에 없는 팀은 API 영문명을 그대로 둔다(에러 아님).
```
Mexico→멕시코, Canada→캐나다, USA/United States→미국, Brazil→브라질, Argentina→아르헨티나,
France→프랑스, Spain→스페인, Germany→독일, England→잉글랜드, Portugal→포르투갈,
Netherlands→네덜란드, Italy→이탈리아, Belgium→벨기에, Croatia→크로아티아, Uruguay→우루과이,
Morocco→모로코, Japan→일본, South Korea/Korea Republic→대한민국, Senegal→세네갈, Switzerland→스위스,
Denmark→덴마크, Poland→폴란드, Colombia→콜롬비아, Ecuador→에콰도르, Serbia→세르비아,
Iran→이란, Australia→호주, Ghana→가나, Egypt→이집트, Nigeria→나이지리아, Austria→오스트리아,
Peru→페루, Qatar→카타르, Tunisia→튀니지, Cameroon→카메룬, Panama→파나마, Costa Rica→코스타리카,
Saudi Arabia→사우디아라비아, New Zealand→뉴질랜드, Uzbekistan→우즈베키스탄, Ivory Coast→코트디부아르,
Slovenia→슬로베니아, South Africa→남아프리카공화국, Jordan→요르단, New Caledonia→뉴칼레도니아
```

## 5. 원자적 저장
- 결과를 `data.js` 파일에 쓴다. 반드시 임시 파일(`data.js.tmp`)에 먼저 쓰고, 유효하면(중괄호 균형·`window.WC_DATA =` 로 시작) `data.js` 로 교체(이동)한다. 절대 반쯤 쓰다 만 파일을 남기지 마라.
- `sample` 필드는 제거한다(실데이터이므로).
- 실패 시 기존 `data.js` 를 건드리지 말고 오류 한 줄만 출력.

## 6. 마무리 출력(한 줄)
`갱신: 이벤트요청 N건, 총 API요청 M건, updatedAt=<시각>`
