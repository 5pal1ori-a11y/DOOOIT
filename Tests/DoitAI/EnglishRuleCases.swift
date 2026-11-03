import Foundation

// MARK: - 영어 문법 엔진: 단원별 규칙 (틀린 문장은 찾고, 닮은 바른 문장은 그대로) + 바른 문장 정밀도 모음

struct EnglishRuleCase {
    let level: String
    let topic: String
    /// 틀린 문장 → 고친 말에 들어 있어야 할 낱말 ("" 이면 찾기만 확인)
    let wrong: [(String, String)]
    /// 닮았지만 바른 문장 (아무것도 걸리면 안 됨)
    let right: [String]
}

let englishRuleCases: [EnglishRuleCase] = [
    // MARK: 초등~중1
    EnglishRuleCase(level: "초등~중1", topic: "명사 주어 수일치", wrong: [
        ("My brother play soccer every day.", "plays"), ("The students is in the classroom.", "are"), ("My parents was very busy.", "were"),
        ("The boxes on the table is heavy.", "are"), ("The girl with long hair are my sister.", "is"), ("These apples is delicious.", "are"),
        ("The children plays in the park.", "play"), ("People is kind here.", "are"), ("The news are surprising.", "is"),
        ("The police is looking for the thief.", "are"), ("My friends likes pizza.", "like"), ("This book are interesting.", "is")
    ], right: [
        "My brother plays soccer every day.", "The students are in the classroom.", "The boxes on the table are heavy.", "The girl with long hair is my sister.",
        "My family is large.", "The team are wearing new uniforms.", "Two hours is enough.", "The number of students is small.", "A number of students are absent.",
        "The book store opens at nine.", "The United States is a large country.", "My brother and sister are students.", "The sheep are eating grass.",
        "The news is good.", "Physics is difficult.", "The rich are not always happy.", "Each student has a locker.", "The key to the doors is lost.",
        "If the boy were here, he would help us.", "The people in the room are quiet."
    ]),
    EnglishRuleCase(level: "초등~중1", topic: "A and B · 이름 주어", wrong: [
        ("Tom and I is good friends.", "are"), ("My sister and my brother likes music.", "like"), ("Minsu like apples.", "likes"),
        ("Jisu are my best friend.", "is"), ("Tom often play tennis.", "plays"), ("He and she is classmates.", "are")
    ], right: [
        "Tom and I are good friends.", "Minsu likes apples.", "Jisu is my best friend.", "Tom often plays tennis.", "Slow and steady wins the race.",
        "Kindly help me.", "Japanese eat a lot of rice.", "The singer and actor is famous."
    ]),
    EnglishRuleCase(level: "초등~중1", topic: "There is/are · 지시사 · one of", wrong: [
        ("There is some apples in the box.", "are"), ("There are a lot of water in the bottle.", "is"), ("There is no books on the desk.", "are"),
        ("I like this shoes.", ""), ("Those book are mine.", "books"), ("These pencil is new.", "pencils"), ("One of my friend lives in Busan.", "friends"),
        ("He is one of the best player in the team.", "players"), ("Each of the student has a book.", "students")
    ], right: [
        "There is some milk in the cup.", "There are a lot of people here.", "There is a lot of water.", "These days I am busy.", "Those who help others are happy.",
        "This news is great.", "One of my friends lives in Busan.", "One of the family members is sick.", "These kind of books are popular."
    ]),
    EnglishRuleCase(level: "초등~중1", topic: "셀 수 없는 명사 · 관사", wrong: [
        ("He gave me an advice.", ""), ("I need some informations.", "information"), ("We bought new furnitures.", "furniture"),
        ("I have many homework today.", ""), ("She ate a apple.", "an"), ("It is an useful book.", "a")
    ], right: [
        "He gave me a piece of advice.", "I need some information.", "I have a lot of homework today.", "It was a homework assignment.", "She is an honest girl.",
        "It is a useful book.", "He has a good knowledge of history."
    ]),
    EnglishRuleCase(level: "초등~중1", topic: "인칭대명사의 격 · 소유", wrong: [
        ("He went to the zoo with I.", "me"), ("I love she very much.", "her"), ("Me and my friend went shopping.", "I"), ("Him is my brother.", "He"),
        ("This book is my.", "mine"), ("This is mine pen.", "my"), ("The dog wagged it's tail.", ""), ("Its a beautiful day.", "It's"),
        ("This is a secret between you and I.", "me"), ("Thank you for inviting we.", "us")
    ], right: [
        "He went to the zoo with me.", "I love her very much.", "My friend and I went shopping.", "This book is mine.", "This is my pen.",
        "The dog wagged its tail.", "It's a beautiful day.", "How about we go to the park?", "He is taller than I am.", "I think he is right.",
        "She sings like she means it.", "This pen is yours and that one is mine."
    ]),
    EnglishRuleCase(level: "초등~중1", topic: "의문문", wrong: [
        ("Is your parents at home?", "Are"), ("Do your brother like soccer?", "Does"), ("What does he likes?", "like"), ("Where did you went yesterday?", "go"),
        ("Where you live?", ""), ("What you are doing now?", ""), ("How many books you have?", ""), ("What is your hobbies?", "")
    ], right: [
        "Are your parents at home?", "Does your brother like soccer?", "What does he like?", "Where did you go yesterday?", "Where do you live?",
        "What are you doing now?", "How many books do you have?", "What did you do last weekend?", "What do you think he likes?", "Who did it?",
        "Are the book and the pen yours?", "What are your plans for the weekend?", "When you came home, did you eat dinner?"
    ]),
    EnglishRuleCase(level: "초등~중1", topic: "진행형 · 명령문 · be동사와 일반동사", wrong: [
        ("I am play soccer now.", "playing"), ("They are study in the library.", "studying"), ("She is knowing the answer.", ""), ("Don't late for school.", "be late"),
        ("Let's going to the park.", "go"), ("Let's to play outside.", ""), ("Please opens the door.", "open"), ("I am agree with you.", "")
    ], right: [
        "I am playing soccer now.", "Don't be late for school.", "Let's go to the park.", "Let's not go there.", "Please open the door.", "I agree with you.",
        "I am free today.", "Without your help, I couldn't have finished it.", "He is clean and tidy.", "We are ready.", "She is like her mother.", "Don't worry about it.", "I am like you."
    ]),
    EnglishRuleCase(level: "초등~중1", topic: "비교 기본", wrong: [
        ("He is very taller than me.", "much"), ("She is tallest girl in my class.", "the tallest"), ("He is as tall than his father.", "as"),
        ("My bag is heavier as yours.", ""), ("He runs faster than any other boys in his class.", "boy"), ("This is superior than that.", "to"),
        ("The harder you study, the best grade you will get.", "better"), ("I prefer tea than coffee.", "to")
    ], right: [
        "He is much taller than me.", "She is the tallest girl in my class.", "He is as tall as his father.", "My bag is heavier than yours.",
        "He runs faster than any other boy in his class.", "This is superior to that.", "The harder you study, the better grade you will get.", "I prefer tea to coffee.",
        "She is happier as a teacher.", "Which is fastest, a car or a train?", "I would rather stay home than go out.", "She became happier as she grew older."
    ]),
    EnglishRuleCase(level: "초등~중1", topic: "시간 전치사 · 전치사 없는 동사", wrong: [
        ("I was born on 2010.", "in"), ("We have a test in Monday.", "on"), ("He gets up in 7 o'clock.", "at"), ("Her birthday is at July.", "in"),
        ("The party is in July 4th.", "on"), ("I usually read books at night and at the morning.", "in"), ("We discussed about the problem.", ""),
        ("She resembles with her mother.", ""), ("We arrived to Seoul late.", "at")
    ], right: [
        "I was born in 2010.", "We have a test on Monday.", "He gets up at 7 o'clock.", "Her birthday is in July.", "The party is on July 4th.",
        "I read books at night.", "We discussed the problem.", "She resembles her mother.", "We arrived in Seoul late.", "He arrived to find the door locked.",
        "I will finish it in 10 minutes.", "On the morning of May 5, we left."
    ]),
    // MARK: 중2~중3
    EnglishRuleCase(level: "중2~중3", topic: "현재완료", wrong: [
        ("I have went to Jeju twice.", "gone"), ("She has ate lunch already.", "eaten"), ("When have you finished your homework?", ""),
        ("I have finished it just now.", ""), ("I have gone to Paris twice.", "been"), ("I know him for ten years.", "known"),
        ("We have lived here since three years.", "for"), ("Have you ever gone to London?", "been")
    ], right: [
        "I have been to Jeju twice.", "She has already eaten lunch.", "When did you finish your homework?", "I finished it just now.", "He has gone to Paris.",
        "I have known him for ten years.", "We have lived here for three years.", "It has been three years since I came here.", "I had a cold last week.",
        "She has lived here since 2015.", "I study for two hours every day."
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "수동태", wrong: [
        ("The accident was happened last night.", "happened"), ("The bridge will be build next year.", "built"), ("He was made go out.", "to go"),
        ("I born in 2008.", "was born"), ("She is interested about science.", "in"), ("The box was filled of toys.", "with"),
        ("The window broke by Tom.", "was broken"), ("The meeting was disappeared from the list.", ""), ("He is proud at his son.", "of")
    ], right: [
        "The accident happened last night.", "The bridge will be built next year.", "He was made to go out.", "I was born in 2008.", "She is interested in science.",
        "The box was filled with toys.", "The window was broken by Tom.", "The window broke by itself.", "The mountain is covered with snow.",
        "He is known for his kindness.", "She is good to me.", "The house was built in 1990.", "A baby is born every second."
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "to부정사", wrong: [
        ("It is kind for you to help me.", "of"), ("It is important of us to exercise.", "for"), ("He is enough old to drive.", "old enough"),
        ("He was too tired that he couldn't walk.", "so"), ("This box is too heavy to lift it.", ""), ("I don't know how swim.", "to swim"),
        ("I need a chair to sit.", "sit on"), ("She wants to goes home.", "go"), ("I want you go there.", "to go")
    ], right: [
        "It is kind of you to help me.", "It is important for us to exercise.", "He is old enough to drive.", "He was so tired that he couldn't walk.",
        "This box is too heavy to lift.", "I don't know how to swim.", "I need a chair to sit on.", "She wants to go home.", "I want you to go there.",
        "It is nice for us to have a break.", "It is too late to change it.", "The man was too weak to lift it.", "I know how come he left."
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "동명사", wrong: [
        ("Thank you for help me.", "helping"), ("He left without say goodbye.", "saying"), ("I am used to get up early.", "getting"),
        ("I can't help laugh at the joke.", "laughing"), ("She is busy to prepare dinner.", "preparing"), ("How about go to the movies?", "going"),
        ("I feel like eat pizza.", "eating"), ("This book is worth to read.", "reading"), ("He finished to read the book.", "reading"), ("They planned visiting Paris.", "")
    ], right: [
        "Thank you for helping me.", "He left without saying goodbye.", "I am used to getting up early.", "I used to get up early.", "The knife is used to cut bread.",
        "I can't help you.", "How about a walk?", "I feel like eating pizza.", "This book is worth reading.", "I kind of like it.", "Ask for help.",
        "I stopped to buy some water.", "He did nothing except eat."
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "감정 분사", wrong: [
        ("The movie was bored.", "boring"), ("I am interesting in music.", "interested"), ("I felt boring at the party.", "bored"),
        ("The news made me surprising.", "surprised"), ("The game was excited.", "exciting"), ("She was disappointing with the result.", "disappointed")
    ], right: [
        "The movie was boring.", "I am interested in music.", "I felt bored at the party.", "The news made me surprised.", "He is interesting.", "He is boring at parties.",
        "She is amazing at math.", "The class was bored.", "I feel amazing today.", "He is interesting in many ways."
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "관계대명사 · 관계부사", wrong: [
        ("This is the house in that he lives.", "which"), ("My brother, that lives in Seoul, is a doctor.", "who"), ("This is the book what I bought.", "which"),
        ("This is the way how he solved it.", ""), ("I know a girl who father is a pilot.", "whose"), ("This is the book which I bought it yesterday.", ""),
        ("This is the house which I was born.", "where"), ("I remember the day which we first met.", "when"), ("This is the city where I visited last year.", "which"),
        ("I have a friend who live in Canada.", "lives"), ("The boys who plays soccer are my classmates.", "play")
    ], right: [
        "This is the house in which he lives.", "My brother, who lives in Seoul, is a doctor.", "This is the book which I bought.", "This is how he solved it.",
        "I know a girl whose father is a pilot.", "This is the house which I was born in.", "This is the house where I was born.", "I remember the day when we met.",
        "This is the city which I visited last year.", "I have a friend who lives in Canada.", "The boys who play soccer are my classmates.",
        "He bought such a big car that he loves it.", "I asked the teacher what he meant.", "The man and the woman who are talking are my parents.",
        "This is the town which my family visited."
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "접속사 · 상관접속사", wrong: [
        ("I stayed home because of I was sick.", "because"), ("We canceled the game because the bad weather.", "because of"),
        ("Despite he was tired, he kept working.", "although"), ("I fell asleep during I was reading.", "while"), ("I don't know if or not he will come.", "whether"),
        ("Both Tom and Jane is students.", "are"), ("Either you or he are wrong.", "is"), ("Neither my sister nor my parents likes fish.", "like"),
        ("Unless you don't hurry, you will be late.", ""), ("Although it was cold, but we went out.", ""), ("It was so a nice day.", "such")
    ], right: [
        "I stayed home because I was sick.", "We canceled the game because of the bad weather.", "Although he was tired, he kept working.",
        "I fell asleep while I was reading.", "I don't know whether or not he will come.", "Both Tom and Jane are students.", "Either you or he is wrong.",
        "Neither my sister nor my parents like fish.", "Unless you hurry, you won't make it.", "Although it was cold, we went out.", "It was such a nice day.",
        "She as well as her friends is coming.", "Not only you but also he is wrong."
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "부사절 · 간접의문문 · 부가의문문", wrong: [
        ("I will call you as soon as he will arrive.", ""), ("I don't know where does he live.", ""), ("Do you know where is the station?", ""),
        ("Do you think where he lives?", ""), ("You are a student, are you?", "aren't you"), ("He likes pizza, isn't he?", "doesn't he"),
        ("She can swim, doesn't she?", "can't she"), ("Let's go, will you?", "shall we")
    ], right: [
        "I will call you as soon as he arrives.", "I don't know where he lives.", "Do you know where the station is?", "Where do you think he lives?",
        "You are a student, aren't you?", "He likes pizza, doesn't he?", "She can swim, can't she?", "Let's go, shall we?", "I don't know when he will come.",
        "I'm not sure if he will come.", "I will ask him if he will join us.", "I am late, aren't I?", "He never studies, does he?", "There is a book, isn't there?"
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "가정법", wrong: [
        ("I wish I am rich.", "were"), ("I wish I can fly.", "could"), ("If I had studied harder, I will pass the exam.", ""),
        ("If I had studied harder, I would pass the exam.", ""), ("If I would have known, I would have told you.", "had"), ("If I were you, I will go there.", "would")
    ], right: [
        "I wish I were rich.", "I wish I could fly.", "If I had studied harder, I would have passed the exam.", "If I had eaten breakfast, I wouldn't be hungry now.",
        "If I had known, I would have told you.", "If you would like some tea, let me know.", "I wish you a merry Christmas.", "I wish to see you again.",
        "If he had left earlier, he would be here now."
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "사역 · 지각동사 · 목적격 보어", wrong: [
        ("My mom made me cleaning my room.", "clean"), ("I had him to fix the car.", ""), ("I saw him to cross the street.", ""), ("I had my car wash.", "washed"),
        ("He asked me help him.", "to help"), ("She told us leaving early.", "to leave"), ("He let me using his phone.", "use")
    ], right: [
        "My mom made me clean my room.", "I had him fix the car.", "I saw him cross the street.", "I had my car washed.", "He asked me to help him.", "I had my hair cut.",
        "She told us to leave early.", "He let me use his phone.", "I have him to thank for this.", "I had my room clean.", "I got him home safely.",
        "I watched him to learn how to do it."
    ]),
    EnglishRuleCase(level: "중2~중3", topic: "수일치 더", wrong: [
        ("Most of the water are polluted.", "is"), ("All of the students is here.", "are"), ("Playing computer games are fun.", "is"), ("To learn languages are useful.", "is"),
        ("Watching movies are my hobby.", "is")
    ], right: [
        "Most of the water is polluted.", "All of the students are here.", "Playing computer games is fun.", "Running shoes are expensive.", "Reading glasses are useful.",
        "Eating habits are important.", "To learn languages is useful.", "Playing children are noisy."
    ]),
    // MARK: 고1~수능
    EnglishRuleCase(level: "고1~수능", topic: "분사구문", wrong: [
        ("Writing in easy English, the book is good for beginners.", "Written"), ("Seeing from the sky, the island looks like a heart.", "Seen"),
        ("He listened with his eyes closing.", "closed"), ("She stood with her arms folding.", "folded")
    ], right: [
        "Written in easy English, the book is good for beginners.", "Seen from the sky, the island looks like a heart.", "He listened with his eyes closed.",
        "Walking down the street, I met an old friend.", "Generally speaking, the plan is good.", "Judging from his face, he is angry.", "He sat with tears running down his face."
    ]),
    EnglishRuleCase(level: "고1~수능", topic: "도치 · 강조", wrong: [
        ("Never I have seen such a beautiful sight.", ""), ("Little he knew about the plan.", ""), ("Only then I realized my mistake.", ""),
        ("Not until yesterday I knew the truth.", ""), ("She likes pizza, and so am I.", "do"), ("He can swim, and so do I.", "can"),
        ("He didn't come, and so did she.", "neither"), ("Here is your books.", "are"), ("On the hill stand an old castle.", "stands"),
        ("It was yesterday which I met him.", "that"), ("Never did I saw him again.", "see")
    ], right: [
        "Never have I seen such a beautiful sight.", "Little did he know about the plan.", "Only then did I realize my mistake.", "Not until yesterday did I know the truth.",
        "She likes pizza, and so do I.", "He can swim, and so can I.", "He didn't come, and neither did she.", "Here are your books.", "On the hill stands an old castle.",
        "It was yesterday that I met him.", "Never mind.", "It was in the park which I love.", "Only you can help me."
    ]),
    EnglishRuleCase(level: "고1~수능", topic: "병렬구조 · 동사와 준동사", wrong: [
        ("She enjoys reading books and to watch movies.", "watching"), ("He opened the door and walk in.", "walked"), ("She gets up early and go jogging.", "goes"),
        ("The man lives next door is very kind.", "living"), ("He going to school every day.", "is going")
    ], right: [
        "She enjoys reading books and watching movies.", "He opened the door and walked in.", "She gets up early and goes jogging.", "He told me to come and help.",
        "The man living next door is very kind.", "The man who lives next door is very kind.", "He is going to school.", "I saw him going to school.",
        "She has to cook dinner and watching TV is fun for her.", "He let the dog out and closed the door."
    ]),
    EnglishRuleCase(level: "고1~수능", topic: "형용사와 부사", wrong: [
        ("You look happily today.", "happy"), ("The soup tastes deliciously.", "delicious"), ("She sings beautiful.", "beautifully"), ("It was terrible cold.", "terribly"),
        ("He works hardly every day.", "hard"), ("She arrived lately for the meeting.", "late"), ("The music sounds strangely.", "strange")
    ], right: [
        "You look happy today.", "The soup tastes delicious.", "She sings beautifully.", "It was terribly cold.", "He works hard every day.", "He hardly works.",
        "He looked carefully at the map.", "She looked sadly at me.", "He appeared suddenly.", "I have been busy lately.", "He soon became seriously ill.", "I feel badly about it."
    ]),
    EnglishRuleCase(level: "고1~수능", topic: "재귀대명사 · 대명사", wrong: [
        ("I looked at me in the mirror.", "myself"), ("He hurt myself while playing.", "himself"), ("Myself went there.", "I"),
        ("The ears of a rabbit are longer than that of a cat.", "those"), ("The population of Seoul is larger than those of Busan.", "that")
    ], right: [
        "I looked at myself in the mirror.", "He hurt himself while playing.", "I myself went there.", "She looked at her in the mirror.",
        "The ears of a rabbit are longer than those of a cat.", "The population of Seoul is larger than that of Busan.", "He asked me to help myself.", "I bought it for me."
    ]),
    EnglishRuleCase(level: "고1~수능", topic: "조동사 심화", wrong: [
        ("You should have went to the doctor.", "gone"), ("He must have forget the meeting.", "forgotten"), ("You had better to go now.", ""),
        ("I would rather to stay home.", ""), ("I used to playing the piano.", "play"), ("I use to live in Busan.", "used")
    ], right: [
        "You should have gone to the doctor.", "He must have forgotten the meeting.", "You had better go now.", "You had better not go.", "I would rather stay home.",
        "I used to play the piano.", "I am used to playing the piano.", "I didn't use to like it.", "You must have to wait."
    ]),
    EnglishRuleCase(level: "고1~수능", topic: "자동사 · 타동사", wrong: [
        ("The cat is laying on the sofa.", "lying"), ("The sun raises in the east.", "rises"), ("He rose his hand.", "raised"), ("He lied on the bed.", "lay")
    ], right: [
        "The cat is lying on the sofa.", "The sun rises in the east.", "He raised his hand.", "He lay on the bed.", "She laid the book on the desk.", "He lied to me.",
        "He was raised by his grandmother.", "Prices rose the next day.", "Hens lay eggs."
    ]),
    EnglishRuleCase(level: "고1~수능", topic: "명사절 · 가목적어", wrong: [
        ("That I want is your love.", "What"), ("I hope what you will get well soon.", "that"), ("I heard the news what he won the prize.", "that"),
        ("I believe what he is honest.", "that"), ("I found difficult to solve the problem.", "it difficult"), ("He made possible to finish the work.", "it possible")
    ], right: [
        "What I want is your love.", "I hope that you will get well soon.", "I heard the news that he won the prize.", "I believe that he is honest.",
        "I found it difficult to solve the problem.", "Make sure to lock the door.", "Feel free to ask questions.", "That he lied is clear.", "I know what he likes."
    ])
]

// MARK: 바른 문장 모음 (교과서 · 시험 지문 문장) — 하나라도 걸리면 실패

let englishPrecisionSuite: [String] = [
    // 초등~중1
    "I am a middle school student.", "My name is Minsu.", "She is from Canada.", "They are my classmates.", "We were at the library yesterday.",
    "He has two sisters and a brother.", "My father works at a bank.", "My mother teaches English at a high school.", "The cat sleeps on the sofa.",
    "Tom goes to school by bus.", "Jane doesn't like spicy food.", "Do you have any pets?", "Does your sister play the violin?", "Did they win the game?",
    "I can ride a bike.", "She can't speak Chinese.", "You must wear a helmet.", "We will visit our grandparents next week.", "It will rain tomorrow.",
    "Look! The baby is sleeping.", "Listen! Someone is singing.", "They are playing basketball now.", "What are you doing?", "I was watching TV at that time.",
    "Be careful.", "Don't run in the hallway.", "Please be quiet in the library.", "Let's take a break.", "Open your books to page ten.",
    "Who is your favorite singer?", "What time is it now?", "Where is the restroom?", "When is your birthday?", "Why are you so happy?", "How was your trip?",
    "How many students are there in your class?", "How much is this shirt?", "Which season do you like best?", "Whose bag is this?",
    "There is a bakery across the street.", "There are many trees in the park.", "There was a big storm last night.", "There were few people on the street.",
    "This is my best friend, Jisu.", "That is a beautiful flower.", "These are my old photos.", "Those shoes are too small for me.",
    "My brother is taller than me.", "This is the most exciting game.", "Summer is hotter than spring.", "She is the youngest in her family.",
    "I get up at six thirty every morning.", "We have lunch at noon.", "The store opens at nine on weekdays.", "School starts in March.",
    "I was born in 2011.", "We go camping in summer.", "He came home late at night.", "See you on Friday.", "The concert is on May 5.",
    "My uncle lives in New York.", "The book is on the desk.", "The ball is under the chair.", "She is waiting at the bus stop.",
    "I have a cold.", "She bought an umbrella.", "He is an engineer.", "It was an honor to meet you.", "I ate an orange and a banana.",
    "The children are playing in the playground.", "Two men are talking outside.", "Many people visit Jeju every year.", "Mice are small animals.",
    "I need some water.", "Can I have a glass of milk?", "She gave me some good advice.", "We don't have much time.", "He has a few friends in Seoul.",
    "Her parents are doctors.", "Our school has a large gym.", "Their house is near the river.", "Its color is bright red.", "Is this pen yours?",
    "I like him a lot.", "She helped us with the project.", "Tell me about your family.", "Give it to me, please.", "They invited me to the party.",
    // 중2~중3
    "I have lived in this town for five years.", "She has just finished her homework.", "Have you ever eaten Thai food?", "He has never been abroad.",
    "They have already left for the airport.", "I haven't seen him since last Monday.", "How long have you studied English?", "She has gone to Busan.",
    "The letter was written by my grandmother.", "This song is loved by many teenagers.", "The museum was built in 1975.", "The thief was caught by the police.",
    "English is spoken all over the world.", "The room is cleaned every day.", "The game will be played tomorrow.", "The work has been finished.",
    "The top of the mountain is covered with snow.", "This table is made of wood.", "Cheese is made from milk.", "She is satisfied with her new job.",
    "I am worried about the test.", "He was surprised at the news.", "Seoul is known for its delicious food.", "The glass is filled with juice.",
    "I want to be a doctor in the future.", "She decided to study abroad.", "He hopes to win the contest.", "We need something to drink.",
    "I went to the store to buy some milk.", "She was happy to hear the news.", "It is fun to learn new things.", "It is dangerous to swim here.",
    "It was very kind of you to say so.", "It is hard for me to wake up early.", "He is too young to watch the movie.", "She is smart enough to solve it.",
    "I don't know what to say.", "Please tell me where to go.", "He taught me how to play chess.", "She has no friends to talk with.",
    "I enjoy listening to music.", "He gave up smoking last year.", "Would you mind closing the door?", "She is good at drawing pictures.",
    "I am looking forward to seeing you soon.", "He is proud of being a teacher.", "Thank you for coming to my party.", "She left without saying a word.",
    "Swimming is good for your health.", "Reading books is my hobby.", "My dream is to travel around the world.", "Learning a new language takes time.",
    "Look at the sleeping baby.", "The boy wearing a red cap is my cousin.", "I found a broken window.", "The book written by him became a bestseller.",
    "The movie was really exciting.", "I was excited about the trip.", "The lecture was boring.", "The students were bored.", "It was a surprising result.",
    "She is the girl who won the race.", "This is the cake which my mom made.", "I have a friend whose father is a firefighter.", "He is the man that I met at the station.",
    "The pen that I lost was expensive.", "What he said made me happy.", "This is what I wanted to buy.", "I know the reason why she left.",
    "This is the place where we first met.", "I still remember the day when I graduated.", "That is how I learned to swim.", "Tell me the way you did it.",
    "I think that he is honest.", "I know that she is busy.", "The problem is that we have no time.", "I wonder if it will snow tomorrow.",
    "I'm not sure whether he will come or not.", "When I got home, my sister was cooking.", "If it rains tomorrow, we will stay home.", "As soon as I arrive, I will call you.",
    "Although she was tired, she finished the report.", "Because it was raining, we stayed inside.", "He studied hard so that he could pass the test.",
    "She is so kind that everyone likes her.", "Both my brother and I like soccer.", "You can have either tea or coffee.", "Neither he nor I am a student.",
    "Not only Tom but also his friends were late.", "I like spring as well as fall.", "Do you know who she is?", "I wonder what he wants.",
    "Can you tell me how old he is?", "I asked her where she lived.", "Who do you think will win?", "You like apples, don't you?", "She isn't busy, is she?",
    "They went to the beach, didn't they?", "He can drive, can't he?", "If I were a bird, I could fly to you.", "If I had more time, I would learn the guitar.",
    "I wish I had a younger brother.", "He talks as if he knew everything.", "If she had been there, she would have helped us.", "I wish I had studied harder.",
    "My teacher made us write an essay.", "Let me introduce myself.", "She had her hair cut short.", "I heard someone calling my name.", "I saw her enter the room.",
    "He helped me move the boxes.", "My parents want me to become a lawyer.", "The doctor told me to rest for a few days.", "He asked me not to tell anyone.",
    "Every child needs love.", "Each of the rooms has a window.", "Mathematics is my favorite subject.", "The news was shocking.", "Ten dollars is enough for lunch.",
    "The number of tourists is increasing.", "A number of people were waiting outside.", "Some of the cake is left.", "Most of my friends live nearby.",
    "He said that he would come back.", "She told me that the earth goes around the sun.", "We learned that Columbus discovered America in 1492.",
    // 고1~수능
    "Feeling tired, she went to bed early.", "Having finished his work, he went home.", "Not knowing what to do, I called my mom.", "The weather being fine, we went out.",
    "Seen from a distance, the rock looks like a face.", "She sat on the bench with her legs crossed.", "He was reading a book with the radio on.",
    "Never have I heard such a strange story.", "Hardly had he arrived when it began to rain.", "Only after the meeting did I understand the problem.",
    "Rarely does he eat breakfast.", "Not until he lost his health did he realize its value.", "So tired was she that she fell asleep at once.",
    "I like jazz, and so does my father.", "She didn't go to the party, and neither did I.", "Here comes the bus.", "Down came the rain.",
    "It was Tom that broke the window.", "It is in the morning that I feel most alive.", "It was not until midnight that he came home.",
    "He likes hiking, swimming, and playing tennis.", "She wants to travel, to learn, and to grow.", "He came in, sat down, and opened his book.",
    "The students who study hard get good grades.", "The book that has a red cover is mine.", "One of the girls who live next door is my friend.",
    "The houses on this street are very old.", "The color of the leaves changes in fall.", "The list of names was posted on the wall.",
    "This flower smells sweet.", "The idea sounds great.", "He looked tired after work.", "The milk turned sour.", "She remained calm during the test.",
    "He drives carefully.", "She speaks English fluently.", "The weather is pretty good today.", "He hardly ever eats meat.", "I have seen him lately.",
    "She introduced herself to the class.", "Help yourself to the cookies.", "We enjoyed ourselves at the festival.", "He did it by himself.",
    "The climate of Korea is milder than that of Russia.", "The prices of vegetables are higher than those of last year.", "He may have missed the bus.",
    "You should have called me earlier.", "She must have been tired.", "He cannot have said such a thing.", "I used to go fishing with my dad.",
    "You had better take an umbrella.", "I would rather walk than take a taxi.", "I couldn't help laughing at his joke.", "She is busy preparing for the exam.",
    "The sun rises in the east.", "She raised her voice.", "The book lies on the table.", "He laid his coat on the chair.", "The boy lay down on the grass.",
    "What matters is your effort.", "That the earth is round is a fact.", "The fact that he lied surprised us.", "I believe that honesty is the best policy.",
    "I found it hard to believe his story.", "They made it possible to travel faster.", "I think it important to keep promises.",
    "It is important that we protect the environment.", "It seems that he is sick.", "He seems to know the answer.", "It is said that he is rich.",
    "The more you practice, the better you get.", "The older he grew, the wiser he became.", "This box is three times as heavy as that one.",
    "No other student in the class is as tall as Minho.", "He is taller than any other boy in the class.", "She is one of the most famous singers in Korea.",
    "Whether he comes or not doesn't matter.", "I don't know whether she likes me.", "Unless it rains, we will play outside.", "By the time he arrived, the movie had started.",
    "Despite the heavy rain, the game continued.", "In spite of his efforts, he failed.", "During the summer vacation, I visited my aunt.", "While I was in Paris, I met him.",
    "Many students think that science is difficult.", "Some people believe that animals have feelings.", "Scientists have found that sleep improves memory.",
    "People who exercise regularly tend to live longer.", "Plants need sunlight to grow.", "Water boils at 100 degrees Celsius.", "The Earth moves around the Sun.",
    "Technology has changed the way we live.", "Social media allows people to share information quickly.", "Recycling helps protect the environment.",
    "Many animals are in danger because of climate change.", "Reading helps children develop their imagination.", "Music can make people feel better.",
    "He spent all his money buying clothes.", "I had difficulty finding the house.", "It is no use crying over spilt milk.", "There is no point in arguing.",
    "She stopped talking when the teacher came in.", "Remember to bring your passport.", "I will never forget meeting you.", "Try turning it off and on again.",
    "The boy who I thought was honest lied to me.", "He gave me a book, which made me happy.", "I met a girl whose name was Alice.", "This is the hotel where we stayed.",
    "That was the year when the war ended.", "Everything that he said was true.", "All you need is love.", "Whoever comes first will get a prize.",
    "Whatever you do, do your best.", "However hard you try, you can't finish it in a day.", "No matter what happens, I will be on your side.",
    "Should you need any help, please call me.", "Had I known the truth, I would have told you.", "Were I in your shoes, I would accept the offer.",
    "Without water, nothing could live.", "But for your help, I would have failed.", "It is time you went to bed.", "I'd rather you didn't smoke here.",
    "The teacher had the students clean the classroom.", "I got my bike repaired.", "She watched the sun go down.", "I felt the house shake.",
    "He was seen to enter the building.", "They were made to wait for hours.", "She was heard singing in the room.", "The children were told to be quiet.",
    "Little did I dream that I would win.", "On the wall hangs a beautiful painting.", "Among the guests was a famous actor.", "In the box were three kittens.",
    "So do I.", "Neither can I.", "Me too.", "Yes, I do.", "No, thank you.", "Excuse me, where is the bank?", "Nice to meet you.", "See you later.",
    "Thank you very much.", "I'm sorry to hear that.", "It doesn't matter.", "That sounds like a good idea.", "I can't wait to see you.",
    "Would you like something to drink?", "May I help you?", "Could you do me a favor?", "Why don't we go out for dinner?", "What do you think of it?",
    "How about going to the beach?", "What about you?", "I'm afraid I can't go.", "I'm good at math but bad at science.", "I'm interested in history.",
    "He is my best friend, and I trust him.", "We went shopping and bought some clothes.", "She was hungry, so she ate a sandwich.", "I tried hard, but I failed.",
    "You can go out after you finish your homework.", "Before you leave, turn off the lights.", "Wait here until I come back.", "Call me when you get there."
]
