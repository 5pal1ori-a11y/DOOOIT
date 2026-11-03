import Foundation

// MARK: - 영어 문장 어법 규칙 (DoitSentenceCheck): 틀린 문장은 찾고, 바른 문장은 틀렸다고 하지 않기

func runSentenceCheckCases() {
    let wrong = [
        "They was at home yesterday.", "He play soccer after school.", "They plays the piano.", "She don't like milk.",
        "Does she likes music?", "Did he went to the library?", "He can speaks English.", "She will comes back.", "You must to go.",
        "I have seen the movie yesterday.", "He goes there yesterday.", "I live here since 2010.", "She told that she was tired.",
        "He said me that he was busy.", "If I were you, I will go there.", "If it will rain tomorrow, I will stay home.",
        "He finished to read the book.", "They planned visiting Paris.", "I am looking forward to see you.", "He made me to wait.",
        "She is more taller than me.", "He is the most smartest boy.", "She is tall than her sister.", "I know the girl which lives next door.",
        "This is the book who I like.", "This is the thing what I wanted.", "This letter was wrote by Tom.", "The bridge was build in 1990.",
        "He has many money.", "I have three book.", "There is three apples.", "There are a dog in the yard.", "He ate a apple.",
        "He bought an new car.", "Is they your friends?", "Do she like cats?", "Every student are happy.", "He has two foots.",
        "We has a dog.", "I has a cat.", "He doesn't knows it.", "She can't swims.", "They will went there.", "Each of the students have a book."
    ]
    for s in wrong {
        check("영어 어법 규칙: 틀린 곳 찾기 — \(s)", DoitSentenceCheck.error(in: s) != nil)
    }
    let right = [
        "She plays the piano every day.", "They were at home yesterday.", "I have lived here since 2015.", "He went to the park last Sunday.",
        "We are watching TV now.", "He put the book on the desk.", "She read the letter.", "I cut the paper.", "We let him go.",
        "I wish I had a car.", "She suggested that he go home.", "It's time we left.", "I am interested in music.", "She is good at tennis.",
        "He has a lot of friends.", "Two dollars is enough for the ticket.", "He said that practice makes perfect.", "If I were you, I would go there.",
        "I don't know if he will come.", "When will you come back?", "The man who I met was kind.", "Thank you for your help.",
        "She told me that she was tired.", "I said to him that I was busy.", "My mom told me to clean my room.", "There are a lot of people.",
        "There is some milk.", "She is a university student.", "It is a useful book.", "We waited for an hour.", "She is an honest girl.",
        "My father reads a newspaper every morning.", "My sister and I are good friends.", "One of my friends lives in Seoul.",
        "Each of the students has a book.", "Everyone likes him.", "It has been three years since I came here.", "I was broke last month.",
        "He need not go.", "The window was broken by Tom.", "English is spoken in many countries.", "She is the tallest girl in her class.",
        "I want clothing for winter.", "Were I rich, I would buy it.", "He is taller than his brother.", "Tell the teacher what happened.",
        "They helped me carry the box.", "I had my brother fix the computer.", "She has gone to Paris.", "He was born in 2010.",
        "Do you have a pen?", "Was it fun?", "Am I late?", "He and I are classmates.", "You and he are right.", "Let it go.",
        "If it rains tomorrow, I will stay home.", "I enjoy swimming in the sea.", "We hope to see you again.", "Would you mind opening the window?",
        // 교과서에 자주 나오는 바른 문장 (규칙이 잘못 걸리지 않는지)
        "I usually get up at seven.", "She has been to London twice.", "He used to live in Busan.", "They are used to eating spicy food.",
        "I stopped to buy some water.", "She stopped talking.", "I remember meeting her.", "Don't forget to call me.", "He made his son a doctor.",
        "I had my hair cut.", "She let her dog run in the park.", "My mother made me a cake.", "It is easy to learn English.",
        "It is important for us to exercise.", "The girl standing there is my sister.", "The book written by him is famous.", "I saw him cross the street.",
        "I heard her singing.", "This is the house where I was born.", "I remember the day when we met.", "That is why I was late.",
        "What I want is your love.", "The man whose car was stolen called the police.", "He is the boy whom I met yesterday.", "He is the man I met yesterday.",
        "I don't know what to do.", "Tell me how to use it.", "If it is sunny tomorrow, we will go hiking.", "If I had wings, I could fly.",
        "I wish I could speak French.", "As soon as he arrives, I will call you.", "Although it was cold, we went out.", "He is so tired that he can't walk.",
        "She is too young to drive.", "He is old enough to drive.", "Not only you but also he is wrong.", "Both Tom and Jane are students.",
        "Either you or he has to go.", "The number of students is increasing.", "A number of students are absent.", "Each student has his own desk.",
        "Most of the water is polluted.", "Some of the books are mine.", "None of them were there.", "Mathematics is my favorite subject.",
        "The news was surprising.", "Ten years is a long time.", "There are some apples on the table.", "There is a lot of water.",
        "Is there a bank near here?", "Are there any questions?", "How many brothers do you have?", "How much money do you have?",
        "What does he do?", "Where did you go yesterday?", "Who broke the window?", "Which do you like better, tea or coffee?",
        "He runs as fast as his brother.", "She is the most beautiful girl in the class.", "This is much bigger than that.",
        "The more you study, the more you learn.", "He is one of the best players in the world.", "I have known him for ten years.",
        "She has lived here since she was a child.", "They have just arrived.", "Have you ever been to Jeju?", "I have never seen such a beautiful place.",
        "He had already left when I arrived.", "I will have finished it by tomorrow.", "The letter was written by Mina.", "The windows are cleaned every day.",
        "The bridge will be built next year.", "The cake was being made.", "He was given a present.", "I was surprised at the news.",
        "She seems to be happy.", "He wants me to help him.", "I asked her to open the door.", "My father told me not to give up.",
        "She enjoys reading books.", "We finished cleaning the room.", "He decided not to go.", "I'm looking forward to the trip.",
        "Thank you for helping me.", "He is good at playing soccer.", "She is interested in art.", "Let's go to the park.", "Please be quiet.",
        "Don't be late.", "He can't be a liar.", "You must be hungry.", "She may be at home.", "I could not sleep last night.", "We should save energy.",
        "You had better go now.", "He would like to visit Paris.", "It took me two hours to finish it.", "It's time to go to bed.", "He kept me waiting.",
        "She found the book interesting.", "I want something cold to drink.", "He has a lot of homework to do.", "Reading books is fun.",
        "To see is to believe.", "She is a nurse who works at a hospital.", "The dog which is barking is mine.", "He lost the watch that his father gave him.",
        "I bought an MP3 player.", "He is an honest man.", "She is a European.", "It was a unique experience.", "He has a one-year-old son.",
        "It rained a lot yesterday.", "He was at home last night.", "She has a cat and two dogs.", "I need two pieces of paper.",
        "We visited our grandparents last weekend.", "My sister is taller than me.", "This is the cheapest one in the store."
    ]
    for s in right {
        let issue = DoitSentenceCheck.error(in: s)
        check("영어 어법 규칙: 바른 문장은 그대로 — \(s)", issue == nil, issue?.why ?? "")
    }
}
