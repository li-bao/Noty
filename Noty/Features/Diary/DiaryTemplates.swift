import Foundation

/// 日記預設模板結構與清單
public struct DiaryTemplate: Identifiable {
    public let id: String
    public let name: String
    public let icon: String
    public let defaultTitle: String
    public let defaultMood: String
    public let content: String
    
    public static let builtInTemplates: [DiaryTemplate] = [
        DiaryTemplate(
            id: "daily",
            name: "Daily Journal",
            icon: "sun.max",
            defaultTitle: "Daily Reflection",
            defaultMood: "😊",
            content: """
            ### 🌅 Morning Intentions
            - What am I looking forward to today?
            - 

            ### ✨ Highlights of the Day
            - 

            ### 🌙 Evening Gratitude & Reflection
            - What went well?
            - 
            """
        ),
        DiaryTemplate(
            id: "travel",
            name: "Travel Journal",
            icon: "airplane",
            defaultTitle: "Travel Memories",
            defaultMood: "🤩",
            content: """
            ### 📍 Destination & Weather
            - Location: 
            - Weather: 

            ### 🗺️ Places Visited
            - 

            ### 🍜 Local Food & Flavors
            - 

            ### 💭 Memorable Moments
            - 
            """
        ),
        DiaryTemplate(
            id: "study",
            name: "Study Notes",
            icon: "graduationcap",
            defaultTitle: "Learning Notes",
            defaultMood: "😌",
            content: """
            ### 📚 Topic & Subject
            - Topic: 

            ### 💡 Core Insights
            - 

            ### ❓ Questions & Follow-ups
            - 
            """
        ),
        DiaryTemplate(
            id: "weekly",
            name: "Weekly Review",
            icon: "calendar.badge.clock",
            defaultTitle: "Weekly Retrospective",
            defaultMood: "😊",
            content: """
            ### 🏆 Wins & Progress
            - 

            ### 🧗 Obstacles & Lessons
            - 

            ### 🎯 Priorities for Next Week
            - 
            """
        ),
        DiaryTemplate(
            id: "monthly",
            name: "Monthly Review",
            icon: "star.circle",
            defaultTitle: "Monthly Reflections",
            defaultMood: "🤩",
            content: """
            ### 🌟 Major Milestones This Month
            - 

            ### 📸 Most Cherished Moments
            - 

            ### 🚀 Vision for the Coming Month
            - 
            """
        ),
        DiaryTemplate(
            id: "free",
            name: "Free Writing",
            icon: "square.and.pencil",
            defaultTitle: "My Thoughts",
            defaultMood: "😊",
            content: ""
        )
    ]
}
