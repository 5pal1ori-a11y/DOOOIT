import SwiftUI

/// 학교 정보 설정: 학교 찾기 → 학년 · 반 → 저장 (로그인 없이 쓸 수 있어요)
struct SchoolSetupView: View {
    @AppStorage(SettingsKey.schoolSelection) private var raw = ""
    @AppStorage(SettingsKey.schoolHomeHidden) private var homeHidden = false
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var office = ""
    @State private var results: [School] = []
    @State private var truncated = false
    @State private var searching = false
    @State private var message: String?

    @State private var picked: School?
    @State private var grade = 1
    @State private var classNum = 1
    @State private var department = ""
    @State private var departments: [String] = []
    @State private var departmentsComplete = false
    @State private var showDepartment = false
    @State private var loaded = false

    private var current: SchoolSelection? { SchoolSelection.decode(raw) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let current { currentCard(current) }
                searchSection
                if let picked { classSection(picked) }
                homeToggle
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .animation(Motion.quick, value: picked?.id)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle("학교 정보")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(query)|\(office)") { await search() }
        .task(id: "\(picked?.id ?? "")|\(showDepartment)") { await loadDepartments() }
        .onAppear(perform: prepare)
    }

    // MARK: 지금 학교

    private func currentCard(_ selection: SchoolSelection) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selection.school.name)
                    .font(.pt(.body).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(summary(selection))
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("해제") {
                raw = ""
                picked = nil
            }
            .font(.pt(.subheadline))
            .foregroundStyle(Palette.danger)
        }
        .softCard()
    }

    private func summary(_ selection: SchoolSelection) -> String {
        var parts = [selection.school.shortRegion, L("\(selection.grade)학년 \(selection.classNum)반")]
        if !selection.department.isEmpty { parts.append(selection.department) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: 학교 찾기

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: L("학교 찾기")) { EmptyView() }
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("학교 이름", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .accessibilityLabel("지우기")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .softCardBackground(cornerRadius: Radius.field)

                Menu {
                    Picker("지역", selection: $office) {
                        Text("전체 지역").tag("")
                        ForEach(NeisOffice.all, id: \.code) { Text($0.name.loc).tag($0.code) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(office.isEmpty ? L("전체") : (NeisOffice.name(office) ?? office).loc)
                            .font(.pt(.subheadline))
                        Image(systemName: "chevron.down").font(.pt(.caption2).weight(.semibold))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .softCardBackground(cornerRadius: Radius.field)
                }
            }

            if searching && results.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if !results.isEmpty {
                resultList
                if truncated {
                    Text("이름을 더 자세히 쓰면 좁혀져요")
                        .font(.pt(.footnote))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 2)
                }
            } else if let message {
                Text(message)
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
            }
        }
    }

    private var resultList: some View {
        VStack(spacing: 0) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, school in
                if index > 0 { Rectangle().fill(Palette.line).frame(height: 0.5).padding(.leading, 16) }
                Button { pick(school) } label: { schoolRow(school) }
                    .buttonStyle(.pressableRow)
            }
        }
        .softCardBackground()
    }

    private func schoolRow(_ school: School) -> some View {
        let isPicked = picked?.id == school.id
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(school.name)
                    .font(.pt(.body))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(detail(school))
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if isPicked {
                Image(systemName: "checkmark").font(.pt(.subheadline).weight(.semibold)).foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func detail(_ school: School) -> String {
        var parts = [school.shortRegion.loc, school.kind == .other ? school.kindName : school.kind.title.loc]
        if !school.highSchoolType.isEmpty { parts.append(school.highSchoolType) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: 학년 · 반

    private func classSection(_ school: School) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: school.name) { EmptyView() }
            if school.kind.timetableEndpoint == nil {
                Text("이 학교는 시간표를 지원하지 않아요. 급식만 나와요")
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }
            VStack(alignment: .leading, spacing: 14) {
                Text("학년").font(.pt(.subheadline)).foregroundStyle(.secondary)
                PillSegmentedControl(items: Array(school.kind.grades), selection: $grade) { L("\($0)학년") }
                Rectangle().fill(Palette.line).frame(height: 0.5)
                HStack {
                    Text("반").font(.pt(.subheadline)).foregroundStyle(.secondary)
                    Spacer()
                    Text(L("\(classNum)반"))
                        .font(.pt(size: 28, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                        .numberRoll(Double(classNum))
                    Stepper("반", value: $classNum, in: 1...30).labelsHidden()
                }
                if school.kind == .high {
                    Rectangle().fill(Palette.line).frame(height: 0.5)
                    if showDepartment || !department.isEmpty {
                        departmentRow
                    } else {
                        Button { withAnimation(Motion.quick) { showDepartment = true } } label: {
                            Text("학과 고르기 (특성화고 등)").font(.pt(.subheadline)).foregroundStyle(Theme.accent)
                        }
                    }
                    Text("선택과목은 반별 시간표와 다를 수 있어요")
                        .font(.pt(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
            .softCard()

            Button(action: save) { Text("저장하기") }
                .buttonStyle(.primaryFill)
        }
    }

    /// 학과 (고등학교): 학과가 여러 개인 학교는 이름이 같은 반이 학과마다 있어서 골라야 해요. 보통은 비워 두면 돼요
    private var departmentRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("학과").font(.pt(.subheadline)).foregroundStyle(.secondary)
                Spacer()
                if departments.count > 1 {
                    Menu {
                        Button("선택 안 함") { department = "" }
                        ForEach(departments, id: \.self) { name in
                            Button(name) { department = name }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(department.isEmpty ? L("목록") : department).font(.pt(.subheadline))
                            Image(systemName: "chevron.up.chevron.down").font(.pt(.caption2))
                        }
                        .foregroundStyle(Palette.ink)
                    }
                }
            }
            TextField("비워 두면 돼요 (예: 그래픽아트과)", text: $department)
                .font(.pt(.body))
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .frame(height: 40)
                .softCardBackground(cornerRadius: Radius.field)
        }
    }

    private var homeToggle: some View {
        Toggle(isOn: Binding(get: { !homeHidden }, set: { homeHidden = !$0 })) {
            Text("홈에 학교 카드 보이기").font(.pt(.body)).foregroundStyle(Palette.ink)
        }
        .tint(Theme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .softCardBackground()
    }

    // MARK: 동작

    private func prepare() {
        guard !loaded else { return }
        loaded = true
        #if DEBUG
        if UIShot.matches(.schoolSetup) {
            query = "한빛"
            results = SchoolDemo.searchResults
            picked = SchoolDemo.searchResults.first
            grade = 2
            classNum = 3
            return
        }
        #endif
        if let current {
            picked = current.school
            grade = current.grade
            classNum = current.classNum
            department = current.department
        }
    }

    private func pick(_ school: School) {
        Haptics.tap()
        picked = school
        grade = min(max(grade, school.kind.grades.lowerBound), school.kind.grades.upperBound)
        department = ""
        departments = []
        showDepartment = false
    }

    private func save() {
        guard let picked else { return }
        let selection = SchoolSelection(school: picked, grade: grade, classNum: classNum,
                                        department: picked.kind == .high ? department : "")
        raw = selection.encoded() ?? ""
        Haptics.success()
        dismiss()
    }

    private func search() async {
        #if DEBUG
        if UIShot.matches(.schoolSetup) { return }
        #endif
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            results = []
            truncated = false
            searching = false
            message = text.isEmpty ? nil : L("두 글자 이상 써 주세요")
            return
        }
        // 입력이 멈추고 0.4초 뒤에 찾음 (글자를 바꾸면 이 작업이 취소됨)
        try? await Task.sleep(for: .milliseconds(400))
        if Task.isCancelled { return }
        searching = true
        message = nil
        do {
            let found = try await SchoolStore.shared.searchSchools(name: text, office: office)
            if Task.isCancelled { return }
            results = found.schools
            truncated = found.truncated
            message = found.schools.isEmpty ? L("학교를 찾지 못했어요") : nil
        } catch is CancellationError {
            return
        } catch {
            results = []
            truncated = false
            message = SchoolText.errorMessage(error)
        }
        searching = false
    }

    private func loadDepartments() async {
        guard let picked, picked.kind == .high, showDepartment || !department.isEmpty else { departments = []; return }
        #if DEBUG
        if UIShot.matches(.schoolSetup) { return }
        #endif
        let found = await SchoolStore.shared.departments(for: picked)
        if Task.isCancelled { return }
        departments = found.names
        departmentsComplete = found.complete
    }
}
