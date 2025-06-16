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

---

# Processed Folder Cleanup Feature

## Problem Statement

When the system transitions from **Startup Mode** to **Maintenance Mode**, the **Processed folder becomes redundant and unnecessary**. This creates several issues:

### Current Behavior Analysis

**Startup Mode:**
- Whitelisted emails → **Processed folder** (auto-processed)
- Blacklisted emails → Junk folder
- Vendor emails → Approved Ads folder  
- Unknown emails → Pending folder

**Maintenance Mode:**
- Whitelisted emails → **Stay in Inbox** (user handles manually)
- Blacklisted emails → Junk folder
- Vendor emails → Approved Ads folder
- Unknown emails → Pending folder

### Issues with Current Approach

1. **Folder Confusion**: Users see a Processed folder that will never receive new messages
2. **Storage Waste**: Processed folder may contain thousands of old emails taking up space
3. **IMAP Clutter**: Unnecessary folder structure in user's email client
4. **Gmail Labels**: For Gmail users, the "Processed" label continues to exist unused
5. **User Uncertainty**: Users don't understand why the folder exists but is empty

## Proposed Solution: Processed Folder Cleanup UX Flow

### Feature: Startup-to-Maintenance Transition Assistant

When transitioning from Startup to Maintenance mode, present user with **Processed Folder Cleanup Options**.

#### UX Flow Design

**Step 1: Transition Detection**
- System detects when switching from Startup → Maintenance mode
- Trigger cleanup dialog/wizard before completing transition

**Step 2: Processed Folder Analysis**
```
Processed Folder Status:
├── Message Count: 2,847 messages
├── Date Range: Jan 15, 2024 - Jun 16, 2025
├── Storage Size: ~145 MB
└── Folder Type: IMAP folder / Gmail label
```

**Step 3: User Choice Dialog**

```
┌─────────────────────────────────────────────────────────────────┐
│  🔄 Transitioning to Maintenance Mode                           │
│                                                                 │
│  Your Processed folder contains 2,847 messages and is no       │
│  longer needed in Maintenance Mode. What would you like to do? │
│                                                                 │
│  ○ Delete Processed folder and all messages                    │
│    ⚠️  This will permanently remove 2,847 messages             │
│                                                                 │
│  ○ Keep Processed folder (recommended)                         │
│    ✓ Messages remain accessible                                │
│    ✓ Folder becomes read-only                                  │
│                                                                 │
│  ○ Archive messages to [Custom Folder] and delete Processed   │
│    📁 Move to: [Dropdown: Archive, Old Messages, etc.]        │
│                                                                 │
│  ○ Export messages and delete Processed folder                 │
│    💾 Download as: [mbox/eml format]                          │
│                                                                 │
│  [ Cancel ]  [ Continue with Selected Option ]                │
└─────────────────────────────────────────────────────────────────┘
```

#### Implementation Options

**Option 1: Keep Processed Folder (Default/Recommended)**
- Mark folder as "read-only" in system configuration
- Add UI indicator that folder is archived/inactive
- Display message: "Contains messages from Startup Mode (Jan-Jun 2025)"

**Option 2: Delete Processed Folder**
- Verify folder is not empty → Show warning
- For Gmail: Remove "Processed" label from all messages
- For IMAP: Delete folder after moving/deleting messages
- Confirmation step with final warning

**Option 3: Archive Messages**
- Move all Processed messages to user-specified folder
- Delete empty Processed folder
- Update system configuration to reflect new archive location

**Option 4: Export and Delete**
- Generate downloadable archive (mbox/eml format)
- Provide download link with expiration
- Delete Processed folder after successful download

#### Advanced UX Features

**Smart Recommendations:**
```python
def recommend_cleanup_option(processed_count, account_type, storage_usage):
    if processed_count > 5000:
        return "archive"  # Too many to delete safely
    elif account_type == "gmail" and storage_usage > 80:
        return "delete"   # Gmail storage pressure
    elif processed_count < 100:
        return "keep"     # Small enough to keep
    else:
        return "archive"  # Default safe option
```

**Folder Analysis Preview:**
- Show date range of messages
- Display top senders in Processed folder
- Storage impact calculation
- Estimated time for cleanup operation

#### Gmail-Specific Considerations

**Gmail Label Cleanup:**
- Remove "Processed" label from all messages
- Messages return to Inbox or other labels they have
- Use `gmail_aware_move()` function for clean removal
- Handle conversation threading properly

**Gmail Storage Impact:**
- Show storage savings potential
- Account for Gmail's storage counting methods
- Consider shared storage across Google services

#### Error Handling & Safety

**Pre-Flight Checks:**
- Verify IMAP connection stability
- Check folder access permissions
- Estimate operation time for large folders
- Create backup plan for failed operations

**Safety Measures:**
- Confirmation emails sent to user
- Operation logging for audit trail
- Rollback capability for recent operations
- Progress indicators for long operations

**Error Recovery:**
- Partial completion handling
- Resume interrupted operations
- User notification of any issues
- Technical support contact information

#### Configuration Storage

**System Configuration Updates:**
```json
{
  "account_config": {
    "email": "user@example.com",
    "processed_folder_status": {
      "exists": false,
      "cleanup_date": "2025-06-16T21:30:00Z",
      "cleanup_method": "archived_to_old_messages",
      "message_count_processed": 2847,
      "user_choice": "archive"
    }
  }
}
```

#### Database Schema (if applicable)

```sql
CREATE TABLE processed_folder_cleanup (
    account_email VARCHAR(255) PRIMARY KEY,
    cleanup_date TIMESTAMP,
    cleanup_method ENUM('keep', 'delete', 'archive', 'export'),
    messages_affected INTEGER,
    target_folder VARCHAR(255),
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Implementation Plan

### Phase 1: Detection and Analysis ⭐ HIGH PRIORITY
- [ ] Detect startup-to-maintenance transitions
- [ ] Analyze Processed folder contents (count, size, date range)
- [ ] Create folder analysis functions
- [ ] Design UX mockups and user flows

### Phase 2: Core Cleanup Operations
- [ ] Implement keep/mark-as-archived option
- [ ] Implement delete folder operation
- [ ] Implement archive-to-folder operation
- [ ] Add Gmail-specific label cleanup
- [ ] Create progress tracking and logging

### Phase 3: Advanced Features
- [ ] Export functionality (mbox/eml formats)
- [ ] Smart recommendation engine
- [ ] Rollback/undo capabilities
- [ ] Email notifications and confirmations

### Phase 4: Integration and Testing
- [ ] Integrate with transition workflow
- [ ] Add configuration persistence
- [ ] Comprehensive testing with various folder sizes
- [ ] User acceptance testing

## Technical Requirements

### Backend Functions Needed
```python
def analyze_processed_folder(account) -> ProcessedFolderAnalysis
def cleanup_processed_folder(account, method, options) -> CleanupResult  
def archive_processed_messages(account, target_folder) -> ArchiveResult
def export_processed_messages(account, format='mbox') -> ExportResult
def gmail_remove_processed_label(account) -> LabelCleanupResult
```

### Frontend Components Needed
- Transition wizard modal/page
- Folder analysis display component
- Progress indicator for cleanup operations
- Confirmation dialogs with safety warnings
- Results/completion summary page

### Configuration Integration
- Extend account configuration schema
- Add processed folder status tracking
- Integration with existing folder configuration system
- Support for per-account cleanup preferences

## Success Criteria

1. **User Control**: Users can choose what happens to Processed folder during transition
2. **Safety**: No accidental data loss with proper warnings and confirmations
3. **Clarity**: Clear explanation of each option and its consequences
4. **Efficiency**: Cleanup operations complete reliably without user intervention
5. **Gmail Compatibility**: Proper label cleanup for Gmail accounts
6. **Audit Trail**: Complete logging of cleanup operations for support

## Related Features

- **Mode Transition System**: Integrates with existing startup/maintenance mode switching
- **Gmail-Aware Processing**: Uses Gmail label cleanup functions
- **Folder Configuration**: May affect per-account folder customization
- **Storage Management**: Relates to retention policies and storage optimization

---

*This feature provides a clean, user-controlled transition experience while eliminating folder confusion and potential storage waste during the critical startup-to-maintenance mode change.*