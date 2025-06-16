# Gmail-Specific Processing Feature Planning

## Problem Statement

Gmail uses labels/tags instead of traditional IMAP folders, which creates unique challenges for email processing systems designed around folder-based workflows. The current Mail-Rulez system has architectural issues when processing Gmail accounts:

### Current Issues

1. **Label Accumulation**: When processing training folders (e.g., `_Approved`), the training label remains on the message even after adding the destination label (`Processed`). This creates messages with multiple labels that could be reprocessed incorrectly.

2. **Pending Label Persistence**: Messages moved from `Pending` to other destinations retain the `Pending` label, potentially causing reprocessing loops or confusion.

3. **Training Workflow Confusion**: Gmail users see messages in multiple "folders" simultaneously, breaking the clean workflow expectations.

4. **Rule Application Issues**: Custom rules face the same problem - applying an action label doesn't remove the condition label.

## Current Architecture Analysis

### How Standard IMAP Works (Expected)
```
Inbox → Move to Pending → Move to Processed
[Message in Inbox] → [Message in Pending only] → [Message in Processed only]
```

### How Gmail Labels Work (Current Problem)
```
Inbox → Add Pending label → Add Processed label
[Message in Inbox] → [Message in Inbox+Pending] → [Message in Inbox+Pending+Processed]
```

### Code Investigation
- `process_inbox.py` lines 59-61: Uses `mb.move()` operations
- `functions.py` training folder processing: Uses `mb.move()` operations
- No explicit label cleanup or removal functionality found
- imap-tools library `move()` method behavior on Gmail needs verification

## Proposed Solution: Gmail-Aware Processing

### Feature: Gmail Label Management System

#### 1. Gmail Account Detection
```python
def is_gmail_account(account_email: str) -> bool:
    """Detect if account is Gmail-based"""
    gmail_domains = ['gmail.com', 'googlemail.com']
    return any(domain in account_email.lower() for domain in gmail_domains)
```

#### 2. Enhanced Move Operations for Gmail
```python
def gmail_aware_move(mailbox, message_uids, destination_folder, source_folder=None):
    """
    Gmail-specific move that properly handles label cleanup
    
    Args:
        mailbox: IMAP connection
        message_uids: List of message UIDs to move
        destination_folder: Target label/folder
        source_folder: Source label/folder to remove (optional)
    """
    if not message_uids:
        return
        
    # Add destination label
    mailbox.move(message_uids, destination_folder)
    
    # Remove source label if specified (Gmail-specific)
    if source_folder and source_folder != 'INBOX':
        try:
            # Use IMAP STORE command to remove specific label
            for uid in message_uids:
                mailbox.client.uid('STORE', uid, '-X-GM-LABELS', f'"{source_folder}"')
        except Exception as e:
            logging.warning(f"Could not remove source label {source_folder}: {e}")
```

#### 3. Modified Processing Functions

**Enhanced `process_inbox()` for Gmail:**
```python
def process_inbox(account, folder="INBOX", limit=100):
    # ... existing logic ...
    
    if is_gmail_account(account.email):
        # Gmail-specific processing
        gmail_aware_move(mb, whitelisted, processed_folder, 'INBOX')
        gmail_aware_move(mb, blacklisted, junk_folder, 'INBOX') 
        gmail_aware_move(mb, vendorlist, approved_ads_folder, 'INBOX')
        gmail_aware_move(mb, pending, pending_folder, 'INBOX')
    else:
        # Standard IMAP processing
        mb.move(whitelisted, processed_folder)
        mb.move(blacklisted, junk_folder)
        mb.move(vendorlist, approved_ads_folder)
        mb.move(pending, pending_folder)
```

**Enhanced Training Folder Processing:**
```python
def process_folder(list_file, account, start_folder, dest_folder):
    # ... existing logic ...
    
    if is_gmail_account(account.email):
        # Remove training label after processing
        gmail_aware_move(mb, msgs_to_move, dest_folder, start_folder)
    else:
        mb.move(msgs_to_move, dest_folder)
```

#### 4. Gmail Configuration Options

Add Gmail-specific settings to account configuration:
```python
class GmailSettings:
    """Gmail-specific processing settings"""
    cleanup_training_labels: bool = True
    cleanup_pending_labels: bool = True
    preserve_inbox_label: bool = False  # Keep messages in Inbox view
    custom_label_prefix: str = "MailRulez/"  # Prefix for custom labels
```

#### 5. Label Management API

```python
class GmailLabelManager:
    """Manage Gmail labels for email processing"""
    
    def remove_label(self, mailbox, message_uids, label_name):
        """Remove specific label from messages"""
        
    def list_message_labels(self, mailbox, message_uid):
        """Get all labels for a specific message"""
        
    def cleanup_processing_labels(self, mailbox, message_uids):
        """Remove temporary processing labels (Pending, training folders)"""
        
    def apply_retention_with_labels(self, mailbox, folder, age, preserve_labels=None):
        """Apply retention while preserving specified labels"""
```

## Implementation Plan

### Phase 1: Core Gmail Detection and Basic Cleanup ✅ COMPLETED
- [x] Implement Gmail account detection
- [x] Add basic label removal functionality
- [x] Test with Gmail account processing
- [x] Update training folder processing

### Phase 2: Enhanced Gmail Processing ✅ COMPLETED
- [x] Implement gmail_aware_move() function
- [x] Update process_inbox() functions
- [x] Add Gmail-specific configuration options
- [x] Test full processing workflow

### Phase 3: Advanced Gmail Features
- [ ] Implement GmailLabelManager class
- [ ] Add custom label prefix support
- [ ] Enhanced retention policies for labels
- [ ] Performance optimization for label operations

### Phase 4: Rules Engine Integration
- [ ] Update rules engine for Gmail label handling
- [ ] Add Gmail-specific rule templates
- [ ] Test custom rules with label cleanup

## Implementation Status (2025-06-16)

### ✅ COMPLETED: Core Gmail-Aware Processing

**Files Modified:**
- `functions.py` - Added Gmail detection and label management functions
- `process_inbox.py` - Updated both processing functions for Gmail-aware operations
- `tests/test_functions.py` - Updated tests to match new function signatures

**New Functions Implemented:**
1. `is_gmail_account(account_email)` - Detects Gmail accounts by domain
2. `remove_gmail_label(mailbox, message_uids, label_name)` - Removes specific Gmail labels
3. `gmail_aware_move(mailbox, message_uids, destination_folder, source_folder)` - Smart move with label cleanup
4. Enhanced `process_folder()` - Training folder processing with Gmail label cleanup

**Features:**
- ✅ Automatic Gmail account detection
- ✅ Smart label cleanup during message moves
- ✅ Training folder Gmail label management
- ✅ Backward compatibility with non-Gmail accounts
- ✅ Comprehensive error handling and logging
- ✅ Integration with both startup and maintenance processing modes

**Ready for Testing:** Container build and deployment testing of Gmail label cleanup functionality.

## Testing Requirements

### Test Scenarios
1. **Basic Label Cleanup**: Verify training labels are removed after processing
2. **Pending Label Removal**: Confirm Pending labels are cleaned up
3. **Multi-Label Messages**: Test messages with multiple labels
4. **Performance Impact**: Measure impact of additional IMAP operations
5. **Error Handling**: Test label removal failures and fallbacks

### Test Environment
- Gmail account with test messages
- Various label combinations
- Large message volumes for performance testing

## Risk Assessment

### Technical Risks
- **IMAP Performance**: Additional label operations may slow processing
- **Gmail API Limits**: Potential rate limiting on label operations
- **imap-tools Compatibility**: Library may not support advanced label operations

### Mitigation Strategies
- Batch label operations where possible
- Implement retry logic for rate limiting
- Fallback to standard move operations if label removal fails
- Add configuration to disable Gmail-specific processing if needed

## Success Criteria

1. **Clean Workflows**: Messages appear in only their intended "folder" after processing
2. **No Reprocessing**: Processed messages don't get reprocessed due to label confusion
3. **User Experience**: Gmail users see expected folder-like behavior
4. **Performance**: Processing time impact < 20% for Gmail accounts
5. **Reliability**: System gracefully handles Gmail-specific errors

## Future Considerations

### Gmail-Specific Features
- **Conversation Threading**: Handle Gmail's conversation grouping
- **Important Markers**: Respect Gmail's importance indicators
- **Categories**: Integration with Gmail's automatic categorization
- **Search Integration**: Leverage Gmail's powerful search for rule conditions

### Alternative Approaches
- **Gmail API Integration**: Consider using Gmail API instead of IMAP for better label control
- **Hybrid Approach**: IMAP for reading, Gmail API for label management
- **User Configuration**: Let users choose between folder-style vs label-style behavior

## Related Issues

- **Defect #3**: Gmail Conversations Going Straight to Processed (may be resolved by this feature)
- **Defect #4**: Items Going to Approved Ads When Senders Not in Vendors [GMAIL ONLY] (label confusion)

---

*This feature addresses the fundamental architectural mismatch between folder-based email processing and Gmail's label-based system, ensuring clean and predictable email workflows for Gmail users.*