import Foundation

// MARK: - 영어 배터리: 손으로 쓴 시험 문제 (밑줄 지문 · 네모 · 빈칸 · 문장 전환) + 함정

let englishHandBattery: [EnglishBatteryCase] = [
    // MARK: 밑줄 친 부분 중 어법상 틀린 것 (지문 속 ①~⑤)
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nMy grandmother ① lives in a small village. She ② has a garden full of flowers. Every spring, she ③ plants new seeds. Last year, she ④ grow tomatoes and carrots. I ⑤ visit her every summer.", "4"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nThe students ① were excited about the field trip. They ② went to the science museum. The guide ③ showed them many interesting things. One of the exhibits ④ was about space. The trip was really ⑤ bored.", "5"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nMany people ① believe that money brings happiness. However, studies show that people who ② spend money on experiences are happier. Buying things ③ give us joy only for a short time. Experiences, on the other hand, ④ stay in our memory. So it is wise ⑤ to invest in experiences.", "3"),
    EnglishBatteryCase("밑줄", "중2~중3", "29. 밑줄 친 부분 중 어법상 어색한 것은? I have a friend ① who lives in London. He ② sent me a letter last week. In the letter, he told me ③ that he was busy. He asked me ④ visit him next summer. I am looking forward to ⑤ seeing him.", "4"),
    EnglishBatteryCase("밑줄", "초등~중1", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nMy name ① is Jimin. I ② have two brothers. They ③ is very tall. We ④ like playing basketball together. Our team ⑤ won the game yesterday.", "3"),
    EnglishBatteryCase("밑줄", "초등~중1", "다음 글의 밑줄 친 부분 중 어법상 어색한 것은?\nThere ① are many parks in my city. My favorite park ② has a big lake. People ③ ride bikes there. My sister ④ go there every weekend. It ⑤ is a great place to relax.", "4"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nThe bridge ① was built in 1950. It ② connects two towns. Thousands of cars ③ cross it every day. Last year, it ④ was repaired by the city. Now it is ⑤ more safer than before.", "5"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nScientists have found that sleep ① plays an important role in memory. When we sleep, the brain ② organizes information. People who ③ sleeps well remember more. Without enough sleep, it is hard ④ to focus. So you should try ⑤ to get enough rest.", "3"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nI ① have lived in Busan for ten years. I ② moved here when I was five. My school ③ is near the beach. I ④ have gone to the beach yesterday. I ⑤ love this city.", "4"),
    EnglishBatteryCase("밑줄", "고1~수능", "밑줄 친 부분 중, 어법상 틀린 것은? The old castle, ① which stands on a hill, ② attracts many tourists. Visitors can see the beautiful view ③ from the top. Inside the castle ④ are many old paintings. The castle ⑤ was attracted more visitors last year.", "5"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nMy brother is interested ① in cooking. He ② makes dinner for us every Friday. Last Friday, he ③ cooked pasta. It ④ tasted deliciously. We all ⑤ enjoyed it.", "4"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 어색한 것은?\nYesterday I ① went to the library. I wanted ② to borrow some books. The librarian ③ helped me find them. I found a book ④ who was about dinosaurs. I ⑤ read it all night.", "4"),
    EnglishBatteryCase("밑줄", "초등~중1", "밑줄 친 부분 중 어법상 틀린 것은? ① Look at the sky. The birds ② are flying south. Winter ③ is coming soon. We ④ need warm clothes. My mom ⑤ buy a new coat for me yesterday.", "5"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nMinsu ① is good at math. He ② wants to be a scientist. He enjoys ③ to solve difficult problems. His teacher ④ is proud of him. He ⑤ will study hard.", "3"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nIf you want ① to learn a language, practice every day. Watching movies ② helps you learn new words. It is important ③ for you to speak a lot. Don't be afraid ④ of making mistakes. Every mistake ⑤ teach you something.", "5"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nThe man ① standing by the door is my uncle. He ② works for a big company. He ③ has traveled to many countries. He told me ④ that he had visited Egypt. He ⑤ have been to Peru too.", "5"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nI usually ① get up at seven. But this morning I ② got up late. I ③ didn't had breakfast. I ④ ran to the bus stop. Luckily, I ⑤ caught the bus.", "3"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nI don't know ① where she lives. I asked her friends, but nobody ② knew. Maybe she ③ has moved to another city. I wish I ④ knew her address. Do you know ⑤ where does she live?", "5"),
    EnglishBatteryCase("밑줄", "초등~중1", "다음 글의 밑줄 친 부분 중 어법상 어색한 것은?\nThis ① is my room. There ② is a desk and a bed. The desk ③ is next to the window. There ④ is many books on the shelf. I ⑤ love my room.", "4"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nJane ① was born in Canada. She ② came to Korea in 2018. Since then, she ③ has learned Korean. Now she can ④ speaks Korean well. She ⑤ wants to stay here longer.", "4"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nNever ① have I seen such a beautiful sunset. The sky ② was red and orange. My friends and I ③ sat on the beach. We ④ watched the sun go down. I will never forget ⑤ watch it.", "5"),
    EnglishBatteryCase("밑줄", "중2~중3", "밑줄 친 부분 중 어법상 틀린 것을 고르시오. My dog ① is very smart. He can ② open the door. When I come home, he always ③ runs to me. He ④ makes me happy. I bought him a toy ⑤ what he likes.", "5"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nThe number of people ① using smartphones ② has increased. Many people ③ use them to read news. Some people ④ spend hours on social media. Experts say that this habit ⑤ make people tired.", "5"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nLast weekend, my family ① went camping. We ② set up a tent by the river. My father ③ cooked dinner. The food was ④ delicious. We were ⑤ exciting about the trip.", "5"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nThe children ① playing in the yard are my nephews. They ② love to run around. Their mother ③ asked them to come inside. But they didn't ④ listen. They kept ⑤ to play.", "5"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nMy uncle is a pilot. He ① has flown to many countries. He ② is flying to Paris now. He told me that he ③ would bring me a gift. I hope he ④ will come back soon. I ⑤ am waiting for him since last Monday.", "5"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nWhen I was young, I ① used to climb trees. My mom ② was worried about me. She told me ③ not to climb so high. But I didn't ④ listen to her. One day I fell and ⑤ hurt me.", "5"),

    // MARK: (A), (B), (C) 각 네모 안에서 어법에 맞는 표현
    EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nMy sister (A) [enjoys / enjoy] reading. She (B) [has read / have read] many books. Her favorite book (C) [was written / was wrote] by a famous writer.\n① enjoys - has read - was written ② enjoy - has read - was written ③ enjoys - have read - was wrote ④ enjoy - have read - was written ⑤ enjoys - has read - was wrote", "1"),
    EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nI know a girl (A) [who / which] plays the violin. She practices (B) [every day / yesterday] for hours. She is (C) [interested / interesting] in classical music.\n① who - every day - interested ② which - every day - interested ③ who - yesterday - interesting ④ which - yesterday - interested ⑤ who - every day - interesting", "1"),
    EnglishBatteryCase("네모", "초등~중1", "(A), (B), (C)에 들어갈 말로 알맞은 것은?\nThere (A) [is / are] three apples on the table. My brother (B) [eat / eats] one every morning. He (C) [don't / doesn't] like bananas.\n① is - eat - don't ② are - eats - doesn't ③ are - eat - doesn't ④ is - eats - don't ⑤ are - eats - don't", "2"),
    EnglishBatteryCase("네모", "고1~수능", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nThe students (A) [who / which] study hard usually (B) [get / gets] good grades. Studying regularly (C) [is / are] the key to success.\n① who - get - is ② which - get - are ③ who - gets - is ④ which - gets - are ⑤ who - get - are", "1"),
    EnglishBatteryCase("네모", "중2~중3", "다음 (A), (B), (C)의 각 네모 안에서 어법에 맞는 것끼리 짝지은 것은?\nI'm looking forward to (A) [see / seeing] you. Thank you for (B) [invite / inviting] me. I hope (C) [to come / coming] again.\n① see - invite - to come ② seeing - inviting - to come ③ seeing - invite - coming ④ see - inviting - coming ⑤ seeing - inviting - coming", "2"),
    EnglishBatteryCase("네모", "고1~수능", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nThe book (A) [lying / laying] on the desk is mine. It (B) [was given / gave] to me by my aunt. The story (C) [is / are] very touching.\n① lying - was given - is ② laying - was given - is ③ lying - gave - are ④ laying - gave - is ⑤ lying - was given - are", "1"),
    EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)에서 어법에 맞는 말을 고르면?\nIf I (A) [were / am] you, I (B) [would / will] take the job. I wish I (C) [had / have] such a chance.\n① were - would - had ② am - will - have ③ were - will - had ④ am - would - had ⑤ were - would - have", "1"),
    EnglishBatteryCase("네모", "초등~중1", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nLook! The children (A) [are playing / is playing] in the snow. They (B) [are / is] wearing warm jackets. One of them (C) [has / have] a red hat.\n① are playing - are - has ② is playing - are - have ③ are playing - is - has ④ is playing - is - have ⑤ are playing - are - have", "1"),
    EnglishBatteryCase("네모", "고1~수능", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nNever (A) [I have / have I] seen such a big fish. The fish (B) [caught / catching] by my dad was huge. We (C) [had it cooked / had it cook] for dinner.\n① have I - caught - had it cooked ② I have - caught - had it cook ③ have I - catching - had it cooked ④ I have - catching - had it cooked ⑤ have I - caught - had it cook", "1"),
    EnglishBatteryCase("네모", "중2~중3", "다음 (A), (B), (C)의 각 네모 안에서 어법에 맞는 것은?\nIt is kind (A) [of / for] you to help me. It is easy (B) [of / for] me to solve it. She is old (C) [enough / enough to] drive.\n① of - for - enough ② for - of - enough ③ of - of - enough to ④ for - for - enough ⑤ of - for - enough to", "5"),
    EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nI stayed home (A) [because / because of] the rain. (B) [Although / Despite] I was bored, I read a book. I fell asleep (C) [during / while] I was reading.\n① because of - Although - while ② because - Although - during ③ because of - Despite - while ④ because - Despite - during ⑤ because of - Although - during", "1"),
    EnglishBatteryCase("네모", "고1~수능", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nThe ears of an elephant are larger than (A) [that / those] of a horse. The elephant (B) [raises / rises] its trunk to drink. Elephants (C) [live / lives] in groups.\n① those - raises - live ② that - raises - live ③ those - rises - lives ④ that - rises - live ⑤ those - raises - lives", "1"),
    EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nI don't know (A) [where he lives / where does he live]. He (B) [moved / has moved] here two years ago. He seems (C) [to like / liking] this town.\n① where he lives - moved - to like ② where does he live - moved - to like ③ where he lives - has moved - liking ④ where does he live - has moved - liking ⑤ where he lives - moved - liking", "1"),
    EnglishBatteryCase("네모", "초등~중1", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nMy father (A) [is / are] a doctor. He (B) [work / works] at a hospital. He (C) [get / gets] up early every day.\n① is - works - gets ② are - work - get ③ is - work - gets ④ are - works - get ⑤ is - works - get", "1"),
    EnglishBatteryCase("네모", "고1~수능", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nThe movie was (A) [boring / bored], so we left early. We (B) [felt / feel] tired after the long day. My friend suggested (C) [going / to go] home.\n① boring - felt - going ② bored - felt - going ③ boring - feel - to go ④ bored - feel - going ⑤ boring - felt - to go", "1"),
    EnglishBatteryCase("네모", "중2~중3", "(A), (B)의 각 네모 안에서 어법에 맞는 표현으로 짝지어진 것은?\nThis is the house (A) [where / which] I was born. That is the reason (B) [why / which] I love this town.\n① where - why ② which - why ③ where - which ④ which - which ⑤ why - where", "1"),
    EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nThe window (A) [was broken / broke] by the strong wind. The accident (B) [happened / was happened] at night. Nobody (C) [was / were] hurt.\n① was broken - happened - was ② broke - happened - were ③ was broken - was happened - was ④ broke - was happened - were ⑤ was broken - happened - were", "1"),
    EnglishBatteryCase("네모", "고1~수능", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nYou should (A) [have gone / have went] to the party. Everyone (B) [was / were] there. It (C) [was / were] so much fun.\n① have gone - was - was ② have went - was - was ③ have gone - were - were ④ have went - were - was ⑤ have gone - were - was", "1"),
    EnglishBatteryCase("네모", "초등~중1", "다음 (A), (B), (C)에 알맞은 것을 고르면?\nShe (A) [can swim / can swims] very fast. Her brothers (B) [is / are] good swimmers too. They (C) [practice / practices] every morning.\n① can swim - are - practice ② can swims - is - practices ③ can swim - is - practice ④ can swims - are - practice ⑤ can swim - are - practices", "1"),
    EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nMy mom made me (A) [clean / to clean] my room. She also let me (B) [watch / to watch] TV after that. I want her (C) [buy / to buy] me a new desk.\n① clean - watch - to buy ② to clean - watch - buy ③ clean - to watch - to buy ④ to clean - to watch - buy ⑤ clean - watch - buy", "1"),

    // MARK: 빈칸 (문법)
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 들어갈 말로 알맞은 것은?\nMy friends ______ in the library now.\n① is ② are ③ am ④ be ⑤ was", "2"),
    EnglishBatteryCase("빈칸", "초등~중1", "다음 빈칸에 알맞은 것은? She ______ to school every day. ① walk ② walks ③ walking ④ to walk ⑤ walked", "2"),
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 알맞은 말을 고르시오.\nHe ______ a movie yesterday.\n① watch ② watches ③ watched ④ will watch ⑤ watching", "3"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nI have ______ in this city since 2015.\n① live ② lived ③ living ④ lives ⑤ to live", "2"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 가장 적절한 것은?\nThe song was ______ by a famous singer.\n① sing ② sang ③ sung ④ singing ⑤ sings", "3"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 알맞은 말은?\nShe finished ______ the report.\n① write ② writing ③ to write ④ wrote ⑤ writes", "2"),
    EnglishBatteryCase("빈칸", "중2~중3", "다음 빈칸에 들어갈 말로 알맞은 것은?\nWe decided ______ a party.\n① have ② having ③ to have ④ had ⑤ has", "3"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nThis is the boy ______ won the race.\n① which ② who ③ what ④ whose ⑤ where", "2"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 알맞은 관계사는?\nI met a woman ______ son is a famous actor.\n① who ② which ③ whose ④ that ⑤ whom", "3"),
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 들어갈 말로 알맞은 것은?\nThis bag is ______ than that one.\n① cheap ② cheaper ③ cheapest ④ more cheap ⑤ most cheap", "2"),
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 알맞은 것은? He is the ______ boy in our class. ① tall ② taller ③ tallest ④ more tall ⑤ most tall", "3"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nThank you for ______ me.\n① help ② helping ③ to help ④ helped ⑤ helps", "2"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nThe news made everyone ______.\n① surprise ② surprising ③ surprised ④ to surprise ⑤ surprises", "3"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nI am interested ______ history.\n① at ② on ③ in ④ with ⑤ about", "3"),
    EnglishBatteryCase("빈칸", "고1~수능", "빈칸에 들어갈 말로 가장 적절한 것은?\nThe flowers in the vase ______ beautiful.\n① is ② are ③ was ④ be ⑤ being", "2"),
    EnglishBatteryCase("빈칸", "고1~수능", "빈칸에 들어갈 말로 가장 적절한 것은?\nYou look ______ today.\n① happily ② happy ③ happiness ④ happier than ⑤ to happy", "2"),
    EnglishBatteryCase("빈칸", "고1~수능", "빈칸에 들어갈 말로 가장 적절한 것은?\nThe boy ______ next to me is my cousin.\n① sit ② sits ③ sitting ④ sat ⑤ to sitting", "3"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nI saw him ______ the street.\n① cross ② to cross ③ crossed ④ crosses ⑤ to crossing", "1"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 알맞은 말은?\nShe asked me ______ the door.\n① open ② opening ③ to open ④ opened ⑤ opens", "3"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nI'm looking forward to ______ you.\n① meet ② meeting ③ met ④ meets ⑤ be meet", "2"),
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 들어갈 말로 알맞은 것은?\nThere ______ a lot of people at the concert.\n① is ② are ③ was ④ be ⑤ been", "2"),
    EnglishBatteryCase("빈칸", "초등~중1", "다음 빈칸에 들어갈 말로 알맞은 것은?\n______ your sister like K-pop?\n① Do ② Does ③ Is ④ Are ⑤ Did", "2"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nIf I ______ a bird, I could fly.\n① am ② are ③ were ④ be ⑤ is", "3"),
    EnglishBatteryCase("빈칸", "고1~수능", "빈칸에 들어갈 말로 가장 적절한 것은?\nHe must have ______ the bus.\n① miss ② missed ③ missing ④ misses ⑤ to miss", "2"),
    EnglishBatteryCase("빈칸", "고1~수능", "빈칸에 들어갈 말로 가장 적절한 것은?\nI used to ______ the piano.\n① play ② playing ③ played ④ plays ⑤ be played", "1"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nHe has ______ to Japan twice.\n① gone ② been ③ go ④ went ⑤ going", "2"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은? Do you know where he ______? ① live ② lives ③ does live ④ living ⑤ to live", "2"),
    EnglishBatteryCase("빈칸", "고1~수능", "빈칸에 들어갈 말로 가장 적절한 것은?\nThe climate of Korea is milder than ______ of Russia.\n① it ② that ③ those ④ this ⑤ these", "2"),
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 들어갈 말로 알맞은 것은?\nI ______ hungry now.\n① am ② is ③ are ④ be ⑤ were", "1"),
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 들어갈 말로 알맞은 것은?\nThey will ______ a test tomorrow.\n① take ② takes ③ took ④ taking ⑤ taken", "1"),

    // MARK: 문장 전환
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿀 때 빈칸에 알맞은 말을 쓰시오.\nTom broke the window.\n→ The window ______ by Tom.", "was broken"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿔 쓸 때 빈칸에 알맞은 말은?\nMy mother made this cake.\n→ This cake ______ by my mother.", "was made"),
    EnglishBatteryCase("전환", "중2~중3", "다음 두 문장의 뜻이 같도록 빈칸에 알맞은 말을 쓰시오.\nMany people love the song. = The song ______ by many people.", "is loved"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿔 쓰시오.\nShakespeare wrote Hamlet.", "Hamlet was written by Shakespeare."),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바르게 바꾼 것은?\nThe students cleaned the classroom.\n① The classroom is cleaned by the students.\n② The classroom was cleaned by the students.\n③ The classroom were cleaned by the students.\n④ The students was cleaned by the classroom.\n⑤ The classroom cleaned by the students.", "2"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿀 때 빈칸에 알맞은 말을 쓰시오.\nThey will build a new school.\n→ A new school ______ by them.", "will be built"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿀 때 빈칸에 알맞은 말을 쓰시오.\nShe invited me.\n→ I ______ by her.", "was invited"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿀 때 빈칸에 알맞은 말은?\nHe has fixed the computers.\n→ The computers ______ by him.", "have been fixed"),
    EnglishBatteryCase("전환", "중2~중3", "다음 두 문장이 같은 뜻이 되도록 빈칸에 알맞은 말을 쓰시오.\nHe is so tired that he can't walk.\n= He is ______ to walk.", "too tired"),
    EnglishBatteryCase("전환", "중2~중3", "같은 뜻이 되도록 빈칸을 채우시오.\nShe is so rich that she can buy the house.\n= She is rich ______ to buy the house.", "enough"),
    EnglishBatteryCase("전환", "고1~수능", "다음 두 문장의 의미가 같도록 빈칸에 알맞은 말을 쓰시오.\nIt seems that he is sick.\n= He seems ______ sick.", "to be"),
    EnglishBatteryCase("전환", "고1~수능", "다음 두 문장이 같은 뜻이 되도록 빈칸에 알맞은 말을 쓰시오.\nIt seems that she knows the answer.\n= She seems ______ the answer.", "to know"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 가정법으로 바꿀 때 빈칸에 알맞은 말은?\nAs I am not rich, I can't buy the car.\n→ If I ______ rich, I ______ buy the car.", "were / could"),
    EnglishBatteryCase("전환", "중2~중3", "다음 두 문장이 같은 뜻이 되도록 빈칸에 알맞은 말을 쓰시오.\nI'm sorry that I can't swim.\n= I wish I ______ swim.", "could"),
    EnglishBatteryCase("전환", "중2~중3", "같은 뜻이 되도록 바꿔 쓸 때 빈칸에 알맞은 말은?\nI'm sorry I am not tall.\n= I wish I ______ tall.", "were"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장과 같은 뜻이 되도록 빈칸에 알맞은 말을 쓰시오.\nAs I don't have time, I can't help you.\n= If I ______ time, I ______ help you.", "had / could"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿔 쓰시오.\nMy dog bit the mailman.", "The mailman was bitten by my dog."),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿀 때 빈칸에 알맞은 말은?\nPeople speak English all over the world.\n→ English ______ all over the world by people.", "is spoken"),
    EnglishBatteryCase("전환", "중2~중3", "다음 두 문장의 뜻이 같도록 빈칸에 알맞은 말을 쓰시오.\nThe box is so heavy that I can't lift it.\n= The box is too heavy ______ to lift.", "for me"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바르게 바꾼 것은?\nMinho sent the letters.\n① The letters was sent by Minho.\n② The letters were sent by Minho.\n③ The letters are sent by Minho.\n④ The letters were send by Minho.\n⑤ Minho was sent by the letters.", "2")
]

// MARK: 함정: 답이 하나로 안 정해지거나 규칙으로 알 수 없는 것 → 풀면 안 됨

let englishBatteryTraps: [EnglishBatteryCase] = {
    var traps: [EnglishBatteryCase] = [
        // 모두 바른 문장 (어색한 것을 고를 수 없음)
        EnglishBatteryCase("문장고르기", "중2~중3", "다음 중 어법상 어색한 문장은?\n① I stopped to buy a drink.\n② I stopped drinking soda.\n③ Remember to call me.\n④ I remember calling you.\n⑤ Try opening the window.", ""),
        EnglishBatteryCase("문장고르기", "중2~중3", "다음 중 어법상 틀린 것은?\n① He talks as if he is the boss.\n② My family is large.\n③ The team are celebrating.\n④ She has gone to London.\n⑤ I forgot to bring my book.", ""),
        EnglishBatteryCase("문장고르기", "고1~수능", "다음 중 어법상 어색한 문장은?\n① The data show a clear trend.\n② The staff are friendly.\n③ Physics is hard.\n④ The police are coming.\n⑤ Ten dollars is enough.", ""),
        EnglishBatteryCase("문장고르기", "초등~중1", "다음 중 어법상 어색한 문장은?\n① Fish live in water.\n② Sheep eat grass.\n③ Deer run fast.\n④ The fish is big.\n⑤ The sheep are white.", ""),
        // 틀린 문장이 둘 (시험 문제가 잘못됨 → 하나로 못 정함)
        EnglishBatteryCase("문장고르기", "초등~중1", "다음 중 어법상 어색한 문장은?\n① He play soccer.\n② They was happy.\n③ I am a student.\n④ She likes cats.\n⑤ We are friends.", ""),
        EnglishBatteryCase("문장고르기", "중2~중3", "다음 중 어법상 틀린 것은?\n① I have seen it yesterday.\n② She enjoys to swim.\n③ He is kind.\n④ We like music.\n⑤ It is cold.", ""),
        // 옳은 것을 고르는데 틀린 것을 모두 확실히 알 수 없음
        EnglishBatteryCase("문장고르기", "중2~중3", "다음 중 어법상 옳은 문장은?\n① He stopped to smoke.\n② She stopped smoking.\n③ I tried to open it.\n④ I tried opening it.\n⑤ We forgot to lock the door.", ""),
        // 밑줄: 밑줄 오류가 없거나 규칙으로 못 가림
        EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nThe idea ① that animals can feel ② is not new. Many scientists ③ have studied it. They found that dogs ④ can feel joy. Some even say cats ⑤ feel love.", ""),
        EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nI ① stopped to talk to my friend. We ② talked for an hour. Then I ③ remembered to buy milk. I ④ went to the store. I ⑤ forgot buying bread.", ""),
        EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nMy family ① is going on a trip. We ② are leaving tomorrow. My parents ③ have planned it for months. Everyone ④ is excited. We ⑤ will stay for a week.", ""),
        // 밑줄: 틀린 곳이 없거나 한 가지로 정해지지 않음
        EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nThe Amazon rainforest ① is home to millions of species. It ② produces a lot of oxygen. Sadly, large parts of the forest ③ have been destroyed. Many animals ④ are losing their homes. We must protect ⑤ them before it is too late, and we should act now.", ""),
        EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nThe concert ① was held in the park. Many people ② came to see it. The singer ③ was singing beautiful songs. The audience ④ was moved by her voice. It was ⑤ such a wonderful night that nobody wanted to leave.", ""),
        EnglishBatteryCase("밑줄", "초등~중1", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nMy best friend ① is Sora. She ② lives next to my house. We ③ go to school together. She ④ is taller than me. She is the ⑤ smartest girl of my class, and she helps me a lot.", ""),
        // 네모: 두 쪽 모두 맞을 수 있음
        EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nShe likes (A) [to swim / swimming]. He began (B) [to run / running]. They love (C) [to sing / singing].\n① to swim - to run - to sing ② swimming - running - singing ③ to swim - running - singing ④ swimming - to run - to sing ⑤ to swim - to run - singing", ""),
        EnglishBatteryCase("네모", "중2~중3", "(A), (B)의 각 네모 안에서 어법에 맞는 표현으로 짝지어진 것은?\nMy family (A) [is / are] big. The team (B) [is / are] practicing.\n① is - is ② is - are ③ are - is ④ are - are ⑤ none", ""),
        // 빈칸: 뜻에 따라 둘 다 됨
        EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nHe stopped ______ to his friend.\n① talk ② talking ③ to talk ④ talked ⑤ talks", ""),
        EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nI remember ______ the letter.\n① send ② sending ③ to send ④ sent ⑤ sends", ""),
        EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nShe began ______ the piano.\n① play ② playing ③ to play ④ plays ⑤ played", ""),
        EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 들어갈 말로 알맞은 것은?\nMy family ______ big.\n① is ② are ③ am ④ be ⑤ been", ""),
        // 고치기: 틀린 곳이 둘이거나 없음
        EnglishBatteryCase("고치기", "초등~중1", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nHe play soccer and they was happy.", ""),
        EnglishBatteryCase("고치기", "중2~중3", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nShe stopped to talk to him.", ""),
        EnglishBatteryCase("고치기", "중2~중3", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nMy family is going to the beach.", ""),
        // 개수: 맞는 문장이 섞임
        EnglishBatteryCase("개수", "중2~중3", "다음 중 어법상 틀린 문장의 개수는?\n(a) He play soccer.\n(b) She likes cats.\n(c) They was late.\n(d) I am happy.\n① 1개 ② 2개 ③ 3개 ④ 4개 ⑤ 없음", ""),
        // 전환: 정해진 틀이 아님 (4형식 · 목적어 없음)
        EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿔 쓰시오.\nHe gave me a book.", ""),
        EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿔 쓰시오.\nShe sleeps well.", ""),
        EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿔 쓰시오.\nThey seem happy.", "")
    ]
    // 모두 바른 문장 다섯 개 (재료 바른 문장으로)
    let circles = ["①", "②", "③", "④", "⑤"]
    for k in 0..<36 {
        let level = DoitEnglishGrammar.levels[k % 3]
        let rights = poolRight.filter { $0.level == level }.map(\.sentence)
        let items = (0..<5).map { rights[(k * 5 + $0 * 3) % rights.count] }
        guard Set(items).count == 5 else { continue }
        let prompt = k % 2 == 0 ? "다음 중 어법상 어색한 문장은?" : "다음 중 어법상 틀린 것은?"
        traps.append(EnglishBatteryCase("문장고르기", level, prompt + "\n" + items.indices.map { "\(circles[$0]) \(items[$0])" }.joined(separator: "\n"), ""))
    }
    // 바른 문장인데 고치라고 함 (틀린 곳 없음)
    for k in 0..<12 {
        let r = poolRight[(k * 9) % poolRight.count]
        traps.append(EnglishBatteryCase("고치기", r.level, "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\n" + r.sentence, ""))
    }
    return traps
}()

// MARK: 새 문제 (규칙을 다 만든 뒤에 쓴 문제 — 규칙을 맞추며 보지 않음)

let englishBatteryFresh: [EnglishBatteryCase] = [
    EnglishBatteryCase("문장고르기", "초등~중1", "다음 중 어법상 어색한 문장은?\n① My uncle drives a taxi.\n② The kids is playing outside.\n③ We ate pizza for lunch.\n④ She has a red umbrella.\n⑤ I am good at singing.", "2"),
    EnglishBatteryCase("문장고르기", "초등~중1", "다음 중 어법상 틀린 것은? ① Does he speak Japanese? ② They don't eat meat. ③ My cat sleep all day. ④ We were tired last night. ⑤ Can you help me?", "3"),
    EnglishBatteryCase("문장고르기", "초등~중1", "다음 중 어법상 어색한 문장은?\n① There are three windows in my room.\n② I need a new pencil.\n③ He bought an umbrella.\n④ Those boy are my cousins.\n⑤ She is my aunt.", "4"),
    EnglishBatteryCase("문장고르기", "중2~중3", "다음 중 어법상 어색한 문장은?\n① I have known her since 2019.\n② The letter was sent yesterday.\n③ She avoided to answer the question.\n④ He wants to be a chef.\n⑤ We enjoyed the concert.", "3"),
    EnglishBatteryCase("문장고르기", "중2~중3", "다음 중 어법상 틀린 것은?\n① The movie was so boring.\n② I was bored during the class.\n③ The trip was very tiring.\n④ We were exciting about the game.\n⑤ The result was surprising.", "4"),
    EnglishBatteryCase("문장고르기", "중2~중3", "다음 중 어법상 어색한 문장은?\n① This is the park where we played.\n② I have a cousin who lives in Jeju.\n③ The pen which I lost was blue.\n④ She is the girl whom I met.\n⑤ This is the hotel which we stayed.", "5"),
    EnglishBatteryCase("문장고르기", "고1~수능", "다음 중 어법상 어색한 문장은?\n① Rarely does she complain.\n② So tired was he that he slept early.\n③ Never I have been so happy.\n④ Here comes the train.\n⑤ Only then did he smile.", "3"),
    EnglishBatteryCase("문장고르기", "고1~수능", "다음 중 어법상 틀린 것은?\n① The coffee smells good.\n② Her voice sounds sweetly.\n③ He looked tired.\n④ The cake tastes great.\n⑤ You seem happy.", "2"),
    EnglishBatteryCase("문장고르기", "중2~중3", "다음 중 어법상 옳은 문장은?\n① She don't like snakes.\n② He can rides a horse.\n③ They was absent.\n④ I has a brother.\n⑤ We are proud of you.", "5"),
    EnglishBatteryCase("문장고르기", "고1~수능", "다음 중 어법상 바른 문장은?\n① The keys on the table is mine.\n② The color of the leaves are red.\n③ Each of the boys have a bike.\n④ The number of visitors is rising.\n⑤ My friends likes music.", "4"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nOur class ① went on a picnic. We ② had lunch under a big tree. After lunch, we ③ played games. Everyone ④ was happy. We ⑤ come back home at five yesterday.", "5"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nPeople ① who read a lot tend to have a large vocabulary. Reading ② helps them understand new ideas. Children ③ who reads every day do better at school. Parents should ④ encourage their children ⑤ to read.", "3"),
    EnglishBatteryCase("밑줄", "초등~중1", "다음 글의 밑줄 친 부분 중 어법상 어색한 것은?\nMy mom ① is a nurse. She ② works at a hospital. She ③ help sick people. I ④ am proud of her. I ⑤ want to be a nurse too.", "3"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nThe Eiffel Tower ① was built in 1889. It ② is visited by millions of people every year. Many tourists ③ take pictures there. The view from the top ④ is amazing. It is one of the most famous ⑤ building in the world.", "5"),
    EnglishBatteryCase("밑줄", "고1~수능", "다음 글의 밑줄 친 부분 중, 어법상 틀린 것은?\nWhen she was a child, she ① used to live on a farm. She ② fed the chickens every morning. Her father ③ taught her how to ride a horse. She still remembers ④ those days. She wishes she ⑤ can go back.", "5"),
    EnglishBatteryCase("밑줄", "중2~중3", "밑줄 친 부분 중 어법상 틀린 것은? I ① met a girl ② whose name is Yuna. She ③ is good at drawing. She showed me the picture ④ what she drew. It ⑤ was beautiful.", "4"),
    EnglishBatteryCase("밑줄", "중2~중3", "다음 글의 밑줄 친 부분 중 어법상 틀린 것은?\nIt ① was raining hard. I ② forgot to bring my umbrella. My friend ③ shared her umbrella with me. It was kind ④ for her to help me. I ⑤ thanked her.", "4"),
    EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nThe boy (A) [who / which] is wearing glasses is my brother. He (B) [likes / like] reading comics. He reads (C) [every day / yesterday] after school.\n① who - likes - every day ② which - likes - every day ③ who - like - yesterday ④ which - like - every day ⑤ who - likes - yesterday", "1"),
    EnglishBatteryCase("네모", "초등~중1", "(A), (B), (C)에 들어갈 말로 알맞은 것은?\nThere (A) [is / are] a library near my school. It (B) [open / opens] at nine. Many students (C) [go / goes] there after class.\n① is - opens - go ② are - opens - go ③ is - open - goes ④ are - open - goes ⑤ is - opens - goes", "1"),
    EnglishBatteryCase("네모", "고1~수능", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nThe population of Tokyo is larger than (A) [that / those] of Seoul. The city (B) [is / are] very crowded. People there (C) [use / uses] trains a lot.\n① that - is - use ② those - is - use ③ that - are - uses ④ those - are - use ⑤ that - is - uses", "1"),
    EnglishBatteryCase("네모", "중2~중3", "(A), (B), (C)의 각 네모 안에서 어법에 맞는 표현으로 가장 적절한 것은?\nI am interested (A) [in / at] science. I enjoy (B) [doing / to do] experiments. I hope (C) [to become / becoming] a scientist.\n① in - doing - to become ② at - doing - to become ③ in - to do - becoming ④ at - to do - becoming ⑤ in - doing - becoming", "1"),
    EnglishBatteryCase("고치기", "초등~중1", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nMy brother have a new computer.", "~→ has"),
    EnglishBatteryCase("고치기", "초등~중1", "다음 문장에서 어법상 어색한 부분을 고쳐 쓰시오.\nThe girls is singing on the stage.", "~→ are"),
    EnglishBatteryCase("고치기", "중2~중3", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nI have ate breakfast already.", "~→ eaten"),
    EnglishBatteryCase("고치기", "중2~중3", "틀린 곳을 바르게 고쳐 쓰시오. This song was sang by a famous band.", "~→ sung"),
    EnglishBatteryCase("고치기", "중2~중3", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nShe is good at swim.", "~→ swimming"),
    EnglishBatteryCase("고치기", "중2~중3", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nHe gave up to eat fast food.", "~→ eating"),
    EnglishBatteryCase("고치기", "고1~수능", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nThe flowers smell sweetly.", "~→ sweet"),
    EnglishBatteryCase("고치기", "고1~수능", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nYou should have came earlier.", "~→ come"),
    EnglishBatteryCase("고치기", "고1~수능", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nThe man stood with his arms folding.", "~→ folded"),
    EnglishBatteryCase("고치기", "중2~중3", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nI wish I am taller.", "~→ were"),
    EnglishBatteryCase("고치기", "중2~중3", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nIt is important of us to recycle.", "~→ for"),
    EnglishBatteryCase("고치기", "중2~중3", "다음 문장에서 어법상 틀린 부분을 찾아 바르게 고치시오.\nShe made me to laugh.", "~→ 삭제"),
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 들어갈 말로 알맞은 것은?\nMy parents ______ at home now.\n① is ② are ③ am ④ be ⑤ was", "2"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nShe has ______ here for three years.\n① live ② lived ③ living ④ lives ⑤ to live", "2"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nThe window was ______ by the boy.\n① break ② broke ③ broken ④ breaking ⑤ breaks", "3"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 알맞은 말은? He kept ______ for an hour. ① wait ② waiting ③ to wait ④ waited ⑤ waits", "2"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nI have a friend ______ mother is a teacher.\n① who ② which ③ whose ④ that ⑤ what", "3"),
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 들어갈 말로 알맞은 것은?\nThis is the ______ day of my life.\n① happy ② happier ③ happiest ④ more happy ⑤ most happiest", "3"),
    EnglishBatteryCase("빈칸", "중2~중3", "빈칸에 들어갈 말로 알맞은 것은?\nWe are looking forward to ______ you.\n① see ② seeing ③ saw ④ seen ⑤ sees", "2"),
    EnglishBatteryCase("빈칸", "초등~중1", "빈칸에 들어갈 말로 알맞은 것은?\nShe ______ to the gym every Monday.\n① go ② goes ③ going ④ gone ⑤ to go", "2"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿀 때 빈칸에 알맞은 말을 쓰시오.\nMy brother washed the car.\n→ The car ______ by my brother.", "was washed"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바꿔 쓰시오.\nPicasso painted this picture.", "This picture was painted by Picasso."),
    EnglishBatteryCase("전환", "중2~중3", "다음 두 문장의 뜻이 같도록 빈칸에 알맞은 말을 쓰시오.\nShe is so young that she can't drive.\n= She is ______ to drive.", "too young"),
    EnglishBatteryCase("전환", "중2~중3", "다음 두 문장의 뜻이 같도록 빈칸에 알맞은 말을 쓰시오.\nI'm sorry that I don't have a dog.\n= I wish I ______ a dog.", "had"),
    EnglishBatteryCase("전환", "고1~수능", "다음 두 문장이 같은 뜻이 되도록 빈칸에 알맞은 말을 쓰시오.\nIt seems that they are happy.\n= They seem ______ happy.", "to be"),
    EnglishBatteryCase("전환", "중2~중3", "다음 문장을 수동태로 바르게 바꾼 것은?\nThe chef cooks the meals.\n① The meals is cooked by the chef.\n② The meals are cooked by the chef.\n③ The meals were cooked by the chef.\n④ The meals are cook by the chef.\n⑤ The chef is cooked by the meals.", "2"),
    EnglishBatteryCase("보기", "중2~중3", "다음 중 어법상 옳은 것끼리 짝지어진 것은?\na) She enjoys to dance.\nb) He has lived here since 2010.\nc) They was late.\nd) I want to go home.\ne) He can swims.\n① a, b ② b, d ③ c, d ④ a, e ⑤ d, e", "2"),
    EnglishBatteryCase("보기", "초등~중1", "다음 중 어법상 틀린 것끼리 묶인 것은?\na) My dad cooks well.\nb) There is two dogs.\nc) She likes apples.\nd) He don't know me.\ne) We are friends.\n① a, b ② b, d ③ c, d ④ a, e ⑤ d, e", "2"),
    EnglishBatteryCase("개수", "중2~중3", "다음 중 어법상 틀린 문장의 개수는?\n(a) She can sings.\n(b) He don't like it.\n(c) They was busy.\n① 0개 ② 1개 ③ 2개 ④ 3개 ⑤ 4개", "4"),
    EnglishBatteryCase("문장고르기", "고1~수능", "다음 중 어법상 어색한 문장은?\n① What he said was true.\n② I believe that she is honest.\n③ That she needs is time.\n④ The fact that he left surprised me.\n⑤ Whether he comes doesn't matter.", "3"),
    EnglishBatteryCase("문장고르기", "고1~수능", "다음 중 어법상 틀린 것은?\n① He must have left early.\n② You should have seen it.\n③ She may have forgot the time.\n④ They can't have done it.\n⑤ I would have helped you.", "3")
]
