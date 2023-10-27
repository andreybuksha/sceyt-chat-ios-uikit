//
//  ChannelDatabaseSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

public protocol ChannelDatabaseSession {
    
    @discardableResult
    func createOrUpdate(channel: Channel) -> ChannelDTO
    
    @discardableResult
    func createOrUpdate(channel: ChatChannel) -> ChannelDTO
    
    @discardableResult
    func createOrUpdate(channels: [Channel]) -> [ChannelDTO]
    
    func markAsRead(channelId: ChannelId)
    
    @discardableResult
    func add(members: [Member], channelId: ChannelId) -> ChannelDTO?
    
    @discardableResult
    func update(owner: Member, channelId: ChannelId) -> ChannelDTO
    
    @discardableResult
    func createOrUpdate(member: Member, channelId: ChannelId) -> MemberDTO
    
    @discardableResult
    func createOrUpdate(members: [Member], channelId: ChannelId) -> [MemberDTO]
    
    @discardableResult
    func createOrUpdate(member: ChatChannelMember, channelId: ChannelId) -> MemberDTO
    
    func delete(members: [Member], channelId: ChannelId)
    
    func deleteMember(id: UserId, from channelId: ChannelId)
    
    @discardableResult
    func update(draft message: NSAttributedString?, date: Date?, channelId: ChannelId) -> ChannelDTO?
}

extension NSManagedObjectContext: ChannelDatabaseSession {
    
    @discardableResult
    public func createOrUpdate(channel: Channel) -> ChannelDTO {
        let dto = ChannelDTO.fetchOrCreate(id: channel.id, context: self).map(channel)
        if channel.newMessageCount > 0 {
            dto.newMessageCount = max(0, Int64(channel.newMessageCount) - numberOfPendingMarkers(name: DefaultMarker.displayed, in: dto))
        }
        if let createBy = channel.createdBy {
            dto.createdBy = createOrUpdate(user: createBy)
        }
        
        if let message = channel.lastMessage {
            createOrUpdate(message: message, channelId: channel.id)
        }
        
        if let messages = channel.messages {
            createOrUpdate(messages: messages, channelId: channel.id)
        }
        if let members = channel.members {
            createOrUpdate(members: members, channelId: channel.id)
        }
        
        dto.lastReaction = nil
        if let reactions = channel.lastReactions {
            createOrUpdate(reactions: reactions)
        }
        
        if let role = channel.userRole {
            dto.userRole = RoleDTO.fetchOrCreate(name: role, context: self)
        }
        if let messagesClearedAt = channel.messagesClearedAt {
            try? deleteAllMessages(
                channelId: channel.id,
                before: messagesClearedAt
            )
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(channel: ChatChannel) -> ChannelDTO {
        let dto = ChannelDTO.fetchOrCreate(id: channel.id, context: self).map(channel)
        if channel.newMessageCount > 0 {
            dto.newMessageCount = max(0, Int64(channel.newMessageCount) - numberOfPendingMarkers(name: DefaultMarker.displayed, in: dto))
        }
        
        if let members = channel.members {
            if dto.members == nil {
                dto.members = .init()
            }
            
            for member in members {
                let mdto = createOrUpdate(member: member, channelId: channel.id)
                dto.members?.insert(mdto)
            }
        }
        
        if let role = channel.userRole {
            dto.userRole = RoleDTO.fetchOrCreate(name: role, context: self)
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(channels: [Channel]) -> [ChannelDTO] {
        channels.map { createOrUpdate(channel: $0) }
    }
    
    public func markAsRead(channelId: ChannelId) {
        let request = MessageDTO.fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        request.predicate = .init(
            format: "channelId == %lld AND incoming == true AND (deliveryStatus == %d OR deliveryStatus == %d)",
            channelId,
            ChatMessage.DeliveryStatus.sent.intValue,
            ChatMessage.DeliveryStatus.received.intValue
        )
        MessageDTO.fetch(request: request, context: self)
            .forEach {
                $0.deliveryStatus = Int16(ChatMessage.DeliveryStatus.displayed.intValue)
            }
    }
    
    public func deleteChannel(id: ChannelId) {
        try? deleteAllMessages(channelId: id)
        if let dto = ChannelDTO.fetch(id: id, context: self) {
            let deletedObjects: [AnyHashable: Any] = [
                NSDeletedObjectsKey: [dto.objectID]
            ]
            delete(dto)
            mergeChangesWithViewContext(fromRemoteContextSave: deletedObjects)
        }
    }
    
    @discardableResult
    public func add(members: [Member], channelId: ChannelId) -> ChannelDTO? {
        guard let dto = ChannelDTO.fetch(id: channelId, context: self)
        else { return nil }
        members.forEach { member in
            let memberDto = MemberDTO.fetchOrCreate(id: member.id, channelId: channelId, context: self).map(member)
            memberDto.user = createOrUpdate(user: member)
            memberDto.role = RoleDTO.fetchOrCreate(name: member.role, context: self)
            if memberDto.channels == nil {
                memberDto.channels = .init()
            }
            memberDto.channels?.insert(dto)
        }
        
        return dto
    }
    
    @discardableResult
    public func update(owner: Member, channelId: ChannelId) -> ChannelDTO {
        let dto = ChannelDTO.fetchOrCreate(id: channelId, context: self)
        dto.owner = MemberDTO.fetchOrCreate(id: owner.id, channelId: channelId, context: self)
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(member: Member, channelId: ChannelId) -> MemberDTO {
        let dto = MemberDTO.fetchOrCreate(id: member.id, channelId: channelId, context: self).map(member)
        dto.user = createOrUpdate(user: member)
        if !member.id.isEmpty {
            dto.role = RoleDTO.fetchOrCreate(name: member.role, context: self)
        } else {
            dto.role = nil
        }
        let channel = ChannelDTO.fetchOrCreate(id: channelId, context: self)
        if dto.channels == nil {
            dto.channels = .init()
        }
        dto.channels?.insert(channel)
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(member: ChatChannelMember, channelId: ChannelId) -> MemberDTO {
        let dto = MemberDTO.fetchOrCreate(id: member.id, channelId: channelId, context: self)
        dto.user = UserDTO.fetch(id: member.id, context: self)
        if !member.id.isEmpty, let role = member.roleName {
            dto.role = RoleDTO.fetchOrCreate(name: role, context: self)
        } else {
            dto.role = nil
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(members: [Member], channelId: ChannelId) -> [MemberDTO] {
        members.map { createOrUpdate(member: $0, channelId: channelId) }
    }
    
    public func delete(members: [Member], channelId: ChannelId) {
        guard let channel = ChannelDTO.fetch(id: channelId, context: self)
        else { return }
        let toDelete = members.compactMap {
            let member = MemberDTO.fetch(id: $0.id, channelId: channelId, context: self)
            if member?.channels?.remove(channel) != nil {
                return member
            }
            return nil
        }
        toDelete.compactMap { ($0.channels == nil || $0.channels?.count == 0) ? $0 : nil }
            .forEach {
                delete($0)
            }
    }
    
    public func deleteMember(id: UserId, from channelId: ChannelId) {
        if let member = MemberDTO.fetch(id: id, channelId: channelId, context: self),
           let channel = ChannelDTO.fetch(id: channelId, context: self) {
            member.channels?.remove(channel)
        }
    }
    
    @discardableResult
    public func update(draft message: NSAttributedString?, date: Date? = nil, channelId: ChannelId) -> ChannelDTO? {
        let dto = ChannelDTO.fetch(id: channelId, context: self)
        dto?.draft = message
        dto?.draftDate = date?.bridgeDate
        return dto
    }
    
    internal func deleteMembers(predicate: NSPredicate) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: MemberDTO.entityName)
        request.predicate = predicate
        try? batchDelete(fetchRequest: request)
    }
    
    internal func numberOfPendingMarkers(name: String, in channel: ChannelDTO) -> Int64 {
        return 0;
        
        let predicate = NSPredicate(format: "pendingMarkerNames != nil")
            .and(predicate: .init(format: "(channelId == %lld OR (channelId == 0 AND ownerChannel.id == %lld))", channel.id, channel.id))
        let count = MessageDTO.fetch(predicate: predicate, context: self).filter { message in
            message.pendingMarkerNames?.contains(name) == true
        }.count
        log.debug("[MARKER CHECK] numberOfPendingMarkers (\(name)) count: \(count), from server \(channel.newMessageCount)")
        return Int64(count)
    }
}
