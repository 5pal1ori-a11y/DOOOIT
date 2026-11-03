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
        "If it rains tomorrow, I will stay home.", "I enjoy swimming in the sea.", "We hope to see you again.", "Would you mind opening the window?"
    ]
    for s in right {
        let issue = DoitSentenceCheck.error(in: s)
        check("영어 어법 규칙: 바른 문장은 그대로 — \(s)", issue == nil, issue?.why ?? "")
    }
}
