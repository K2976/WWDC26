import SwiftUI
import Observation

enum TypingTestMode: Hashable {
    case time(seconds: Int)
    case words(count: Int)
}

enum TypingState {
    case idle
    case typing
    case finished
}

struct WordToken: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var typed: String = ""
    
    var isCorrectlyTyped: Bool {
        text == typed
    }
    
    var hasErrors: Bool {
        !typed.isEmpty && !text.hasPrefix(typed)
    }
}

@MainActor
@Observable
final class TypingEngine {
    var state: TypingState = .idle
    var mode: TypingTestMode = .time(seconds: 15)
    
    var words: [WordToken] = []
    var currentWordIndex = 0
    var currentInput: String = "" {
        didSet {
            processInput()
        }
    }
    
    var timeRemaining: Int = 0
    var timeElapsed: TimeInterval = 0
    
    var wpm: Int = 0
    var accuracy: Int = 0
    var errors: Int = 0
    
    // Core neutral vocabulary
    private let vocabulary = [
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "it", 
        "for", "not", "on", "with", "he", "as", "you", "do", "at", "this", 
        "but", "his", "by", "from", "they", "we", "say", "she", "or", "an", 
        "will", "my", "one", "all", "would", "there", "their", "what", "so", 
        "up", "out", "if", "about", "who", "get", "which", "go", "me",
        "focus", "calm", "breathe", "flow", "mind", "quiet", "peace", "still", 
        "deep", "clear", "rest", "space", "time", "here", "now", "gentle", "soft"
    ]
    
    private var startTime: Date?
    private var timer: Timer?
    
    init() {
        setupTest()
    }
    
    func setMode(_ newMode: TypingTestMode) {
        mode = newMode
        setupTest()
    }
    
    func setupTest() {
        state = .idle
        currentWordIndex = 0
        currentInput = ""
        wpm = 0
        accuracy = 0
        errors = 0
        timeElapsed = 0
        
        timer?.invalidate()
        timer = nil
        startTime = nil
        
        generateWords()
        
        if case .time(let seconds) = mode {
            timeRemaining = seconds
        } else {
            timeRemaining = 0
        }
    }
    
    private func generateWords() {
        let count: Int
        switch mode {
        case .time: count = 150 // Plenty for 60s
        case .words(let c): count = c
        }
        
        words = (0..<count).map { _ in
            WordToken(text: vocabulary.randomElement() ?? "flow")
        }
    }
    
    private func processInput() {
        if state == .finished { return }
        
        if state == .idle && !currentInput.isEmpty {
            startTest()
        }
        
        // If user typed a space, we commit the current word and move to next
        if currentInput.hasSuffix(" ") {
            let typedWord = currentInput.trimmingCharacters(in: .whitespaces)
            words[currentWordIndex].typed = typedWord
            
            if !words[currentWordIndex].isCorrectlyTyped {
                errors += 1
            }
            
            currentWordIndex += 1
            currentInput = "" // clear input for next word
            
            checkCompletion()
        } else {
            // Update current word's typed text as they type
            if currentWordIndex < words.count {
                words[currentWordIndex].typed = currentInput
            }
        }
    }
    
    private func startTest() {
        state = .typing
        startTime = Date()
        currentWordIndex = 0
        errors = 0
        
        if case .time(let seconds) = mode {
            timeRemaining = seconds
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.timeRemaining -= 1
                    if self.timeRemaining <= 0 {
                        self.finishTest()
                    }
                }
            }
        }
    }
    
    private func checkCompletion() {
        if case .words(let count) = mode, currentWordIndex >= count {
            finishTest()
        } else if currentWordIndex >= words.count {
            // Reached end of generated words (unlikely in time mode, but just in case)
            finishTest()
        }
    }
    
    func finishTest() {
        guard state != .finished else { return }
        state = .finished
        timer?.invalidate()
        timer = nil
        
        let endTime = Date()
        timeElapsed = endTime.timeIntervalSince(startTime ?? endTime)
        if timeElapsed < 1 { timeElapsed = 1 } // Prevent div by zero
        
        var totalCorrectChars = 0
        var totalAttemptedWords = currentWordIndex
        
        // Include the word they were currently typing if time ran out
        if case .time = mode, !currentInput.isEmpty, currentWordIndex < words.count {
            let typedWord = currentInput.trimmingCharacters(in: .whitespaces)
            words[currentWordIndex].typed = typedWord
            if !words[currentWordIndex].isCorrectlyTyped {
                errors += 1
            }
            totalAttemptedWords += 1
        }
        
        var correctWordsCount = 0
        for i in 0..<totalAttemptedWords {
            if words[i].isCorrectlyTyped {
                correctWordsCount += 1
                totalCorrectChars += words[i].text.count + 1 // +1 for the space
            }
        }
        
        let minutes = timeElapsed / 60.0
        wpm = Int(Double(totalCorrectChars / 5) / minutes)
        
        if totalAttemptedWords > 0 {
            accuracy = Int((Double(correctWordsCount) / Double(totalAttemptedWords)) * 100)
        } else {
            accuracy = 0
        }
    }
}
