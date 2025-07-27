import Foundation
import Contacts
import MessageUI

class ContactService: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var friendSuggestions: [FriendSuggestion] = []
    @Published var sentInvites: [ContactInvite] = []
    @Published var isLoadingContacts = false
    @Published var contactsPermissionStatus: CNAuthorizationStatus = .notDetermined
    
    private let supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
        checkContactsPermission()
    }
    
    // MARK: - Contacts Permission
    
    func checkContactsPermission() {
        contactsPermissionStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestContactsPermission() async -> Bool {
        let store = CNContactStore()
        
        do {
            let granted = try await store.requestAccess(for: .contacts)
            await MainActor.run {
                self.contactsPermissionStatus = granted ? .authorized : .denied
            }
            return granted
        } catch {
            print("Contact permission error: \(error)")
            await MainActor.run {
                self.contactsPermissionStatus = .denied
            }
            return false
        }
    }
    
    // MARK: - Load Contacts
    
    @MainActor
    func loadContacts() async {
        guard contactsPermissionStatus == .authorized else {
            print("Contacts permission not granted")
            return
        }
        
        isLoadingContacts = true
        
        do {
            let deviceContacts = try await fetchDeviceContacts()
            let appUsers = await fetchAppUsers(for: deviceContacts)
            
            contacts = deviceContacts.map { deviceContact in
                let appUser = appUsers.first { user in
                    (deviceContact.phoneNumber != nil && user.phone == deviceContact.phoneNumber) ||
                    (deviceContact.email != nil && user.email == deviceContact.email)
                }
                
                return Contact(
                    name: deviceContact.name,
                    phoneNumber: deviceContact.phoneNumber,
                    email: deviceContact.email,
                    isOnApp: appUser != nil,
                    userId: appUser?.id
                )
            }
            
            await loadFriendSuggestions()
            
        } catch {
            print("Failed to load contacts: \(error)")
        }
        
        isLoadingContacts = false
    }
    
    private func fetchDeviceContacts() async throws -> [Contact] {
        return try await withCheckedThrowingContinuation { continuation in
            let store = CNContactStore()
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            
            var deviceContacts: [Contact] = []
            
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    let phoneNumber = contact.phoneNumbers.first?.value.stringValue
                    let email = contact.emailAddresses.first?.value as String?
                    
                    if !name.isEmpty || phoneNumber != nil || email != nil {
                        let deviceContact = Contact(
                            name: name,
                            phoneNumber: phoneNumber,
                            email: email,
                            isOnApp: false,
                            userId: nil
                        )
                        deviceContacts.append(deviceContact)
                    }
                }
                continuation.resume(returning: deviceContacts)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func fetchAppUsers(for contacts: [Contact]) async -> [User] {
        do {
            let phoneNumbers = contacts.compactMap { $0.phoneNumber }
            let emails = contacts.compactMap { $0.email }
            
            let users: [User] = try await supabase.client
                .from("users")
                .select()
                .or("phone.in.(\(phoneNumbers.joined(separator: ","))),email.in.(\(emails.joined(separator: ",")))")
                .execute()
                .value
            
            return users
        } catch {
            print("Failed to fetch app users: \(error)")
            return []
        }
    }
    
    // MARK: - Friend Suggestions
    
    @MainActor
    private func loadFriendSuggestions() async {
        guard let currentUserId = supabase.currentUser?.id else { return }
        
        do {
            // Get contacts who are on the app but not yet friends
            let contactsOnApp = contacts.filter { $0.isOnApp && $0.userId != nil }
            
            let suggestions: [FriendSuggestion] = try await supabase.client
                .from("friend_suggestions_view")
                .select()
                .eq("current_user_id", value: currentUserId)
                .execute()
                .value
            
            friendSuggestions = suggestions.filter { suggestion in
                contactsOnApp.contains { $0.userId == suggestion.userId }
            }
            
        } catch {
            print("Failed to load friend suggestions: \(error)")
            // For now, create friend suggestions from contacts on app
            friendSuggestions = contactsOnApp().compactMap { contact in
                guard let userId = contact.userId else { return nil }
                return FriendSuggestion(
                    userId: userId,
                    username: contact.name,
                    displayName: contact.name,
                    avatarUrl: nil,
                    mutualFriendsCount: 0,
                    isFromContacts: true,
                    contactName: contact.name
                )
            }
        }
    }
    
    // MARK: - Send Invites
    
    func sendInvite(to contact: Contact) async -> Bool {
        guard let currentUserId = supabase.currentUser?.id else { return false }
        
        do {
            let invite = ContactInvite(
                id: UUID(),
                inviterId: currentUserId,
                contactName: contact.name,
                contactPhone: contact.phoneNumber,
                contactEmail: contact.email,
                sentAt: Date(),
                status: .sent
            )
            
            try await supabase.client
                .from("contact_invites")
                .insert([invite])
                .execute()
            
            await MainActor.run {
                self.sentInvites.append(invite)
            }
            
            // Send SMS invite if phone number available
            if let phoneNumber = contact.phoneNumber {
                return await sendSMSInvite(to: phoneNumber, contactName: contact.name)
            }
            
            return true
            
        } catch {
            print("Failed to save invite: \(error)")
            return false
        }
    }
    
    private func sendSMSInvite(to phoneNumber: String, contactName: String) async -> Bool {
        // This would typically integrate with SMS service
        // For now, we'll return true and handle SMS through MessageUI
        return true
    }
    
    // MARK: - Friend Actions
    
    func sendFriendRequest(to userId: UUID) async -> Bool {
        guard let currentUserId = supabase.currentUser?.id else { return false }
        
        do {
            let friendRequest = UserFollow(
                id: UUID(),
                followerId: currentUserId,
                followingId: userId,
                createdAt: Date()
            )
            
            try await supabase.client
                .from("user_follows")
                .insert([friendRequest])
                .execute()
            
            return true
            
        } catch {
            print("Failed to send friend request: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    func contactsOnApp() -> [Contact] {
        return contacts.filter { $0.isOnApp }
    }
    
    func contactsNotOnApp() -> [Contact] {
        return contacts.filter { !$0.isOnApp }
    }
    
    func hasBeenInvited(_ contact: Contact) -> Bool {
        return sentInvites.contains { invite in
            (contact.phoneNumber != nil && invite.contactPhone == contact.phoneNumber) ||
            (contact.email != nil && invite.contactEmail == contact.email)
        }
    }
}