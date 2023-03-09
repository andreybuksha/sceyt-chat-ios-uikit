//
//  Appearance+Formatters.swift
//  SceytChatUIKit
//

import Foundation

public struct Formatters {
    
    public static var userDisplayName: UserDisplayNameFormatter = DefaultUserDisplayNameFormatter()
    
    public static var channelTimestamp: TimestampFormatter = DefaultChannelTimestampFormatter()
    
    public static var channelProfileFileTimestamp: TimestampFormatter = DefaultChannelProfileFileTimestamp()
    
    public static var channelDisplayName: ChannelDisplayNameFormatter = DefaultChannelDisplayNameFormatter()
    
    public static var channelUnreadMessageCount: ChannelUnreadMessageCount = DefaultChannelUnreadMessageCount()
    
    public static var channelMemberCount: ChannelDisplayNameFormatter = DefaultChannelDisplayNameFormatter()
    
    public static var messageListSeparator: MessagesListSeparator = DefaultMessagesListSeparator()
    
    public static var messageTimestamp: TimestampFormatter = DefaultMessageTimestampFormatter()
    
    public static var attachmentTimestamp: TimestampFormatter = DefaultAttachmentTimestampFormatter()

    public static var videoAssetDuration: TimeIntervalFormatter = VideoAssetDurationFormatter()
    
    public static var userPresenceFormatter: UserPresenceFormatter = DefaultUserPresenceFormatter()
    
    public static var fileSize: FileSizeFormatter = DefaultFileSizeFormatter()
    
    public static var initials: InitialsFormatter = DefaultInitialsFormatter()
    
    public init() {}
}
