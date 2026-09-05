import Combine
import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class ComplaintStore: ObservableObject {
    @Published private(set) var complaints: [Complaint] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingCommentsFor: Set<UUID> = []
    @Published private(set) var commentsByReportID: [UUID: [ReportComment]] = [:]
    @Published private(set) var myReports: [Complaint] = []
    @Published private(set) var myComments: [ReportComment] = []
    @Published var errorMessage: String?
    @Published private(set) var pendingSupportIDs: Set<UUID> = []
    @Published private(set) var pendingCommentReportIDs: Set<UUID> = []
    @Published private(set) var pendingCommentIDs: Set<UUID> = []
    @Published private(set) var pendingCommentLikeIDs: Set<UUID> = []

    private unowned let auth: AuthStore

    init(auth: AuthStore) { self.auth = auth }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let client: SupabaseClient
            if auth.isAuthenticated {
                client = try await auth.validClient()
            } else {
                guard let publicClient = auth.publicClient() else { throw SupabaseError.invalidResponse }
                client = publicClient
            }
            complaints = try await client.fetchReports(includeOwnReports: auth.isAuthenticated)
        }
        catch { errorMessage = error.localizedDescription }
    }

    func loadOwnedContent() async {
        do { let client = try await auth.validClient(); async let reports = client.fetchMyReports(); async let comments = client.fetchMyComments(); myReports = try await reports; myComments = try await comments }
        catch { errorMessage = error.localizedDescription }
    }

    func update(_ complaint: Complaint) async throws {
        let client = try await auth.validClient()
        let updated = try await client.updateReport(complaint)
        if let i = complaints.firstIndex(where: { $0.id == complaint.id }) { complaints[i] = updated }
        if let i = myReports.firstIndex(where: { $0.id == complaint.id }) { myReports[i] = updated }
    }

    func delete(_ complaint: Complaint) async throws {
        let client = try await auth.validClient()
        try await client.deleteReport(complaint.id); complaints.removeAll { $0.id == complaint.id }; myReports.removeAll { $0.id == complaint.id }
    }

    @discardableResult
    func add(description: String, category: ComplaintCategory, coordinate: CLLocationCoordinate2D, locationName: String, images: [Data]) async throws -> Complaint {
        let client = try await auth.validClient()
        let complaint = try await client.createReport(description: description, category: category, coordinate: coordinate, locationName: locationName, images: images)
        withAnimation(.spring) { complaints.insert(complaint, at: 0) }
        return complaint
    }

    func toggleSupport(for id: UUID) {
        guard !pendingSupportIDs.contains(id), let index = complaints.firstIndex(where: { $0.id == id }) else { return }
        let enabled = !complaints[index].isSupported
        complaints[index].isSupported = enabled
        complaints[index].supportCount += enabled ? 1 : -1
        pendingSupportIDs.insert(id)
        Task {
            defer { pendingSupportIDs.remove(id) }
            do {
                let client = try await auth.validClient()
                try await client.toggleSeen(for: id, enabled: enabled)
            }
            catch {
                if let currentIndex = complaints.firstIndex(where: { $0.id == id }) {
                    complaints[currentIndex].isSupported = !enabled
                    complaints[currentIndex].supportCount += enabled ? -1 : 1
                }
                errorMessage = "Doğrulama kaydedilemedi. Lütfen tekrar dene."
            }
        }
    }

    func isSupportPending(for id: UUID) -> Bool { pendingSupportIDs.contains(id) }

    func loadComments(for reportID: UUID) async {
        isLoadingCommentsFor.insert(reportID)
        defer { isLoadingCommentsFor.remove(reportID) }
        do {
            let client = try await auth.validClient()
            let comments = try await client.fetchComments(for: reportID)
            commentsByReportID[reportID] = comments
            setCommentCount(comments.count, for: reportID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func comments(for reportID: UUID) -> [ReportComment] { commentsByReportID[reportID] ?? [] }

    func isCommentsLoading(for reportID: UUID) -> Bool { isLoadingCommentsFor.contains(reportID) }

    func addComment(reportID: UUID, body: String) async throws -> ReportComment {
        let client = try await auth.validClient()
        pendingCommentReportIDs.insert(reportID)
        defer { pendingCommentReportIDs.remove(reportID) }
        let comment = try await client.addComment(reportID: reportID, body: body)
        commentsByReportID[reportID, default: []].append(comment)
        incrementCommentCount(for: reportID, by: 1)
        return comment
    }

    func isCommentPending(for reportID: UUID) -> Bool { pendingCommentReportIDs.contains(reportID) }
    func isCommentDeletePending(for commentID: UUID) -> Bool { pendingCommentIDs.contains(commentID) }
    func isCommentLikePending(for commentID: UUID) -> Bool { pendingCommentLikeIDs.contains(commentID) }

    func toggleCommentLike(for commentID: UUID) {
        guard !pendingCommentLikeIDs.contains(commentID) else { return }
        for reportID in commentsByReportID.keys {
            guard let index = commentsByReportID[reportID]?.firstIndex(where: { $0.id == commentID }) else { continue }
            let enabled = !commentsByReportID[reportID]![index].isLiked
            commentsByReportID[reportID]![index].isLiked = enabled
            commentsByReportID[reportID]![index].likeCount += enabled ? 1 : -1
            pendingCommentLikeIDs.insert(commentID)
            Task {
                defer { pendingCommentLikeIDs.remove(commentID) }
                do { try await auth.validClient().toggleCommentLike(commentID: commentID, enabled: enabled) }
                catch {
                    if let currentIndex = commentsByReportID[reportID]?.firstIndex(where: { $0.id == commentID }) {
                        commentsByReportID[reportID]![currentIndex].isLiked = !enabled
                        commentsByReportID[reportID]![currentIndex].likeCount = max(0, commentsByReportID[reportID]![currentIndex].likeCount + (enabled ? -1 : 1))
                    }
                    errorMessage = "Yorum beğenisi kaydedilemedi. Lütfen tekrar dene."
                }
            }
            return
        }
    }
    func avatarURL(for path: String?) -> URL? { (auth.client() ?? auth.publicClient())?.publicAvatarURL(for: path) }
    func reportImageURLs(for complaint: Complaint) -> [URL] { complaint.imagePaths.compactMap { (auth.client() ?? auth.publicClient())?.reportImageURL(for: $0) } }

    func delete(_ comment: ReportComment) async throws {
        let client = try await auth.validClient()
        pendingCommentIDs.insert(comment.id)
        defer { pendingCommentIDs.remove(comment.id) }
        try await client.deleteComment(comment.id)
        myComments.removeAll { $0.id == comment.id }
        for key in commentsByReportID.keys { commentsByReportID[key]?.removeAll { $0.id == comment.id } }
        incrementCommentCount(for: comment.reportID, by: -1)
    }

    private func incrementCommentCount(for reportID: UUID, by delta: Int) {
        if let index = complaints.firstIndex(where: { $0.id == reportID }) {
            complaints[index].commentCount = max(0, complaints[index].commentCount + delta)
        }
        if let index = myReports.firstIndex(where: { $0.id == reportID }) {
            myReports[index].commentCount = max(0, myReports[index].commentCount + delta)
        }
    }

    private func setCommentCount(_ count: Int, for reportID: UUID) {
        if let index = complaints.firstIndex(where: { $0.id == reportID }) {
            complaints[index].commentCount = count
        }
        if let index = myReports.firstIndex(where: { $0.id == reportID }) {
            myReports[index].commentCount = count
        }
    }
}
