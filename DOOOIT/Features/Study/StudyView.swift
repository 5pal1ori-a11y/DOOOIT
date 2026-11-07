import SwiftData
import SwiftUI

/// 공부 탭: 목록(영어 단어 · 오답노트 · 메모장 · 공부 랭킹 · 공부 통계) → AI 목록
struct StudyView: View {
    @Query(sort: \Word.createdAt) private var words: [Word]
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]
    @Query private var mathNotes: [MathNote]

    @AppStorage(SettingsKey.dailyWordGoal) private var wordGoal = 20
    @AppStorage(SettingsKey.wordGoalDoneKey) private var wordGoalDoneKey = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 내 공부: 목록 한 묶음 (오른쪽에 지금 상태)
                    VStack(spacing: 0) {
                        NavigationLink { WordHomeView() } label: {
                            RowLabel(symbol: "book.closed", title: L("영어 단어"), value: wordDetail)
                        }
                        RowDivider()
                        NavigationLink { MathNoteListView() } label: {
                            RowLabel(symbol: "pencil", title: L("오답노트"), value: noteDetail)
                        }
                        RowDivider()
                        NavigationLink { MemoListView() } label: {
                            RowLabel(symbol: "doc.text", title: L("메모장"), value: memos.isEmpty ? L("새 메모") : L("\(memos.count)개"))
                        }
                        RowDivider()
                        NavigationLink { RankingView() } label: {
                            RowLabel(symbol: "trophy", title: L("공부 랭킹"))
                        }
                        RowDivider()
                        NavigationLink { SocialHubView() } label: {
                            RowLabel(symbol: "person.2", title: L("친구 · 그룹"), value: socialDetail)
                        }
                        RowDivider()
                        NavigationLink { StatsView() } label: {
                            RowLabel(symbol: "chart.bar", title: L("공부 통계"))
                        }
                    }
                    .buttonStyle(.pressableRow)
                    .softCardBackground()
                    .staggerIn(index: 0)

                    LearnHubSection()
                        .staggerIn(index: 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .navigationTitle("학습")
            #if DEBUG
            .uiShotPush(.words) { WordHomeView() }
            .uiShotPush(.mathList, .mathNote, .mathNoteText, .mathEmpty, .subjectNote) { MathNoteListView() }
            .uiShotPush(.weakList) { WeakConceptListView() }
            .uiShotPush(.weakness) { WeaknessView() }
            .uiShotPush(.mockExam, .mockResult) { MockExamView() }
            .uiShotPush(.grammar) { UnitStudyView(subject: "중학교 영어", unit: "현재완료") }
            .uiShotPush(.grammarOX) { UnitStudyView(subject: "중학교 영어", unit: "현재완료", initialStep: .ox) }
            .uiShotPush(.grammarProblem) { UnitStudyView(subject: "중학교 영어", unit: "현재완료", initialStep: .problem) }
            .uiShotPush(.weeklyReport) { WeeklyReportView() }
            .uiShotPush(.ranking, .rankingFar) { RankingView() }
            .uiShotPush(.friends, .friendsAdd, .socialIntro) { SocialHubView() }
            .uiShotPush(.groups) { SocialHubView(tab: .groups) }
            .uiShotPush(.groupDetail) { SocialGroupDetailView(groupID: UIShotSocial.groupID) }
            .uiShotCover(.wordSession) { UIShotWordSession() }
            #endif
        }
    }

    /// 친구 · 그룹 줄 오른쪽: 켠 뒤에는 친구 수
    private var socialDetail: String? {
        let n = SocialCenter.shared.state.friends.count
        return SocialCenter.shared.isEnabled && n > 0 ? L("\(n)명") : nil
    }

    private var wordDetail: String {
        if words.isEmpty { return L("단어 추가") }
        if wordGoalDoneKey == Date().dayKey { return L("오늘 완료") }
        let left = min(wordGoal, words.filter { !$0.isLearned }.count)
        return left == 0 ? L("모두 외움") : L("오늘 \(left)개")
    }

    private var noteDetail: String {
        let unsolved = mathNotes.filter { $0.status != .correct }.count
        if mathNotes.isEmpty { return L("문제 찍기") }
        return unsolved > 0 ? L("복습 \(unsolved)개") : L("복습 완료")
    }
}
