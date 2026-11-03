import Foundation

// 표로 만드는 문제 (모양 변화가 규칙적인 것만)
// - 표의 모양은 영어 엔진(DoitEnglish)의 변화표와 한 번 더 맞춰 봐요 (테스트)
// - 틀이 되는 문장은 손으로 써서, 오답 보기를 넣으면 반드시 틀린 문장이 되게 했어요
extension DoitGrammar {
    /// 3인칭 단수 현재: (원형, 3인칭 단수형, 잘못 쓴 모양, 문장)
    static let thirdPersonTable: [(String, String, String)] = [
        ("play", "plays", "My brother ___ soccer after school."),
        ("watch", "watches", "My grandfather ___ the news every evening."),
        ("study", "studies", "Mina ___ English every evening."),
        ("go", "goes", "My sister ___ to bed at ten."),
        ("do", "does", "Junho ___ his homework after dinner."),
        ("have", "has", "Our school ___ a big library."),
        ("wash", "washes", "My dad ___ the dishes after dinner."),
        ("fix", "fixes", "My uncle ___ old bikes on weekends."),
        ("teach", "teaches", "Ms. Park ___ math at our school."),
        ("buy", "buys", "My mom ___ bread at the bakery every morning."),
        ("enjoy", "enjoys", "Tom ___ hiking with his dad."),
        ("brush", "brushes", "The boy ___ his teeth three times a day."),
        ("carry", "carries", "My sister ___ a big bag to school."),
        ("fly", "flies", "The pilot ___ to Tokyo every Monday."),
        ("cry", "cries", "The baby often ___ at night."),
        ("catch", "catches", "Our cat ___ mice in the barn."),
        ("mix", "mixes", "The cook ___ the eggs with milk."),
        ("say", "says", "My teacher always ___ hello to us."),
        ("touch", "touches", "He ___ the screen to start the game."),
        ("push", "pushes", "She ___ the button to open the door.")
    ]

    /// 3인칭 단수형을 잘못 쓴 모양 (watchs, studys, playes, gos, dos, haves)
    static func wrongThird(_ base: String, _ third: String) -> String {
        switch base {
        case "go": return "gos"
        case "do": return "dos"
        case "have": return "haves"
        default: break
        }
        if third.hasSuffix("ies") || third.hasSuffix("es") { return base + "s" }
        return base + "es"
    }

    static func thirdRule(_ base: String, _ third: String) -> String {
        if ["have", "go", "do"].contains(base) { return base == "have" ? "불규칙: has" : "o로 끝나서 -es" }
        if third.hasSuffix("ies") { return "자음 + y → y를 i로 바꾸고 -es" }
        if third.hasSuffix("es") { return "s·x·sh·ch로 끝나서 -es" }
        return "-s를 붙임"
    }

    static func pastRule(_ base: String, _ past: String) -> String {
        if past.hasSuffix("ied") { return "자음 + y → y를 i로 바꾸고 -ed" }
        if base.hasSuffix("e") { return "e로 끝나서 -d만" }
        if past.count == base.count + 3 { return "단모음 + 단자음 → 자음을 한 번 더 쓰고 -ed" }
        return "-ed를 붙임"
    }

    /// 과거형: (원형, 과거형, 과거분사, 잘못 쓴 모양, 문장)
    static let pastTable: [(String, String, String, String)] = [
        ("go", "went", "gone", "My family ___ to the beach last summer."),
        ("eat", "ate", "eaten", "I ___ pizza for lunch yesterday."),
        ("see", "saw", "seen", "We ___ a rainbow after the rain yesterday."),
        ("buy", "bought", "bought", "She ___ a new bag last week."),
        ("make", "made", "made", "Mom ___ a chocolate cake for my birthday last year."),
        ("write", "wrote", "written", "He ___ a letter to his grandma two days ago."),
        ("take", "took", "taken", "They ___ a lot of pictures on the trip last month."),
        ("swim", "swam", "swum", "We ___ in the lake last Saturday."),
        ("come", "came", "come", "My cousin ___ to my house yesterday."),
        ("give", "gave", "given", "My uncle ___ me a nice watch last Christmas."),
        ("find", "found", "found", "I ___ my lost key under the sofa yesterday."),
        ("catch", "caught", "caught", "My dad ___ a big fish last weekend."),
        ("teach", "taught", "taught", "Mr. Lee ___ us science last year."),
        ("sleep", "slept", "slept", "The baby ___ well last night."),
        ("drink", "drank", "drunk", "I ___ a glass of milk this morning."),
        ("break", "broke", "broken", "Someone ___ the window last night."),
        ("lose", "lost", "lost", "Jina ___ her umbrella on the bus yesterday."),
        ("meet", "met", "met", "We ___ our new teacher two weeks ago."),
        ("leave", "left", "left", "The train ___ the station an hour ago."),
        ("forget", "forgot", "forgotten", "I ___ my friend's birthday last month."),
        ("speak", "spoke", "spoken", "She ___ to the principal yesterday."),
        ("ride", "rode", "ridden", "We ___ our bikes along the river last Sunday."),
        ("begin", "began", "begun", "The movie ___ at seven last night."),
        ("play", "played", "played", "We ___ baseball after school yesterday."),
        ("stop", "stopped", "stopped", "The bus ___ in front of the museum ten minutes ago."),
        ("study", "studied", "studied", "I ___ for the test last night."),
        ("shop", "shopped", "shopped", "My mom ___ at the market yesterday."),
        ("cry", "cried", "cried", "The little boy ___ for an hour yesterday."),
        ("live", "lived", "lived", "My grandparents ___ in Jeju ten years ago."),
        ("drop", "dropped", "dropped", "He ___ his phone on the street this morning."),
        ("carry", "carried", "carried", "She ___ the heavy box to the classroom yesterday."),
        ("visit", "visited", "visited", "We ___ the history museum last Friday.")
    ]

    /// 과거형을 잘못 쓴 모양: 불규칙 동사에 -ed (goed), 규칙 동사는 철자 실수 (stoped, studyed, plaied, visitted)
    static func wrongPast(_ base: String, _ past: String) -> String {
        let regular = base.hasSuffix("e") ? base + "d" : base + "ed"
        if past != regularPast(base) { return regular }
        if past.hasSuffix("ied") { return base + "ed" }
        if past.count == base.count + 3 { return base + "ed" }        // stopped → stoped
        if base.hasSuffix("e") { return base + "ed" }                 // lived → liveed
        if base.hasSuffix("y") { return String(base.dropLast()) + "ied" } // played → plaied
        return base + String(base.last!) + "ed"                       // visited → visitted
    }

    /// 규칙 과거형 (표 확인용)
    static func regularPast(_ base: String) -> String {
        if base.hasSuffix("e") { return base + "d" }
        if base.hasSuffix("y"), let before = base.dropLast().last, !"aeiou".contains(before) { return String(base.dropLast()) + "ied" }
        if ["stop", "shop", "drop", "plan"].contains(base) { return base + String(base.last!) + "ed" }
        return base + "ed"
    }

    /// 비교급·최상급: (원급, 비교급, 최상급, 비교급 문장, 최상급 문장)
    static let comparisonTable: [(String, String, String, String, String)] = [
        ("tall", "taller", "tallest", "My brother is ___ than me.", "He is the ___ boy in his class."),
        ("big", "bigger", "biggest", "An elephant is ___ than a horse.", "The blue whale is the ___ animal in the world."),
        ("hot", "hotter", "hottest", "Today is ___ than yesterday.", "August is the ___ month of the year in Korea."),
        ("happy", "happier", "happiest", "She looks ___ than before.", "This is the ___ day of my life."),
        ("easy", "easier", "easiest", "This question is ___ than that one.", "This is the ___ way to learn English."),
        ("heavy", "heavier", "heaviest", "My bag is ___ than yours.", "This is the ___ box in the room."),
        ("fast", "faster", "fastest", "A plane is ___ than a train.", "He was the ___ runner in the world."),
        ("long", "longer", "longest", "The Nile is ___ than the Han River.", "The Nile is the ___ river in the world."),
        ("large", "larger", "largest", "Canada is ___ than Korea.", "Russia is the ___ country in the world."),
        ("young", "younger", "youngest", "My cousin is ___ than me.", "Minsu is the ___ member of our team."),
        ("busy", "busier", "busiest", "Dad is ___ this week than last week.", "Monday is the ___ day of the week for me."),
        ("thin", "thinner", "thinnest", "This book is ___ than that dictionary.", "This is the ___ phone in the store."),
        ("cheap", "cheaper", "cheapest", "The bus is ___ than the taxi.", "This is the ___ bag in the shop."),
        ("beautiful", "more beautiful", "most beautiful", "Jeju is ___ than I expected.", "This is the ___ beach in Korea."),
        ("expensive", "more expensive", "most expensive", "This watch is ___ than that one.", "This is the ___ car in the shop."),
        ("popular", "more popular", "most popular", "Soccer is ___ than baseball in my class.", "Soccer is the ___ sport in the world."),
        ("difficult", "more difficult", "most difficult", "Math is ___ than English for me.", "This is the ___ question on the test."),
        ("famous", "more famous", "most famous", "This singer is ___ than her sister.", "He is the ___ actor in Korea."),
        ("good", "better", "best", "Your idea is ___ than mine.", "This is the ___ pizza in town."),
        ("bad", "worse", "worst", "The weather is ___ today than yesterday.", "That was the ___ movie I have ever seen.")
    ]

    /// 복수형: (단수, 복수, 문장) — 오답은 단수형과 잘못 쓴 모양
    static let pluralTable: [(String, String, String)] = [
        ("box", "boxes", "There are three ___ on the table."),
        ("baby", "babies", "Two ___ are sleeping in the room."),
        ("city", "cities", "We visited three ___ in Italy."),
        ("leaf", "leaves", "Many ___ are falling from the tree."),
        ("knife", "knives", "Be careful with those ___."),
        ("wolf", "wolves", "We heard two ___ in the forest."),
        ("man", "men", "Three ___ are waiting for the bus."),
        ("woman", "women", "Two ___ are talking in the cafe."),
        ("child", "children", "The ___ are playing in the yard."),
        ("tooth", "teeth", "My little brother has six ___."),
        ("foot", "feet", "Both of my ___ hurt after the long walk."),
        ("mouse", "mice", "The cat caught two ___."),
        ("goose", "geese", "There are five ___ on the lake."),
        ("dish", "dishes", "I washed all the ___ after dinner."),
        ("watch", "watches", "The shop sells many ___."),
        ("bus", "buses", "Two ___ arrived at the same time."),
        ("tomato", "tomatoes", "Mom bought five ___ at the market."),
        ("piano", "pianos", "The music room has two ___."),
        ("photo", "photos", "I took many ___ on my trip."),
        ("toy", "toys", "My sister has a lot of ___."),
        ("key", "keys", "I lost two ___ yesterday."),
        ("sheep", "sheep", "Ten ___ are eating grass on the hill."),
        ("deer", "deer", "We saw three ___ in the forest."),
        ("story", "stories", "Grandpa told us two funny ___.")
    ]

    /// 복수형을 잘못 쓴 모양 두 개
    static func wrongPlurals(_ noun: String, _ plural: String) -> [String] {
        var list: [String] = []
        let naive = noun + "s"
        if noun == plural { list += [noun + "s", noun + "es"] }
        if naive != plural { list.append(naive) }
        if plural == noun + "s" { list += noun.hasSuffix("y") ? [String(noun.dropLast()) + "ies", noun + "es"] : [noun + "es", noun + "ies"] }
        if plural.hasSuffix("ies") { list.append(noun + "es") }
        if plural.hasSuffix("ves") { list.append(noun + "es") }
        if plural.hasSuffix("es") && !plural.hasSuffix("ies") && !plural.hasSuffix("ves") { list.append(noun + "ies") }
        if !plural.hasSuffix("s") { list.append(plural + "s") }   // childrens, teeths, mices
        var unique: [String] = []
        for w in list where w != plural && !unique.contains(w) { unique.append(w) }
        return Array(unique.prefix(2))
    }

    /// 단원 키 → 표로 만든 문제
    static func templatedItems() -> [String: [GrammarItem]] {
        var map: [String: [GrammarItem]] = [:]
        func add(_ key: String, _ item: GrammarItem) {
            var t = item
            t.templated = true
            map[key, default: []].append(t)
        }
        for (base, third, frame) in thirdPersonTable {
            add("초등 영어|일반동사", b(frame, third, [base, wrongThird(base, third), base + "ing"],
                                   "3인칭 단수 주어 + 현재: \(base) → \(third) (\(thirdRule(base, third)))", hint: base))
        }
        for (base, past, pp, frame) in pastTable {
            var wrong = [base, wrongPast(base, past)]
            wrong.append(pp != past ? pp : DoitEnglish.ingForm(base))
            let irregular = past != regularPast(base)
            add("중학교 영어|과거시제", b(frame, past, wrong, irregular ? "불규칙 동사: \(base) – \(past) – \(pp)" : "규칙 동사: \(base) → \(past) (\(pastRule(base, past)))", hint: base))
        }
        for (index, row) in comparisonTable.enumerated() {
            let (adj, comp, sup, compFrame, supFrame) = row
            let isMore = comp.hasPrefix("more ")
            let compWrong: [String]
            let supWrong: [String]
            switch adj {
            case "good": compWrong = ["gooder", "more good", "best"]; supWrong = ["better", "most good", "goodest"]
            case "bad": compWrong = ["badder", "more bad", "worst"]; supWrong = ["worse", "most bad", "baddest"]
            default:
                compWrong = isMore ? [adj + "er", adj, sup] : ["more " + adj, adj, sup]
                supWrong = isMore ? [comp, adj + "est", "more " + adj] : [comp, "most " + adj, "more " + adj]
            }
            // 짧은 형용사 앞쪽은 초등, 나머지와 최상급 대부분은 중학교
            let compKey = index < 10 ? "초등 영어|비교 기본" : "중학교 영어|비교 표현"
            let supKey = index < 4 ? "초등 영어|비교 기본" : "중학교 영어|비교 표현"
            let rule = isMore ? "긴 형용사는 more / most + 원급" : (["good", "bad"].contains(adj) ? "불규칙 변화" : "짧은 형용사는 -er / -est")
            add(compKey, b(compFrame, comp, compWrong, "비교급 + than: \(adj) → \(comp) (\(rule))", hint: adj))
            add(supKey, b(supFrame, sup, supWrong, "the + 최상급: \(adj) → \(sup) (\(rule))", hint: adj))
        }
        for (noun, plural, frame) in pluralTable {
            let wrong = (noun == plural ? [] : [noun]) + wrongPlurals(noun, plural)
            add("초등 영어|명사의 복수형", b(frame, plural, wrong, "\(noun)의 복수형은 \(plural)이에요.", hint: noun))
        }
        return map
    }
}
