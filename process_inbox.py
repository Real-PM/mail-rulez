import rules as r
import functions as pf
from config import get_config

def process_inbox(account, folder="INBOX", limit=100):
    """
    Fetches mail from specified server/account and folder.  Compares the from_ attribute against specified sender lists.
    If a sender matches an address in a specified list, message is dispositioned according to defined rules.  If no match,
    mail is sent to Pending folder.
    """
    # Process special rules
    for rule in r.rules_list:
        rule(account)

    mail_list = []
    log = {}
    log["process"] = "Process Inbox"
    # Load Lists using configuration
    whitelist = pf.open_read("white")
    blacklist = pf.open_read("black")
    vendorlist = pf.open_read("vendor")

    log["whitelist count"] = len(whitelist)
    log["blacklist count"] = len(blacklist)
    log["vendorlist count"] = len(vendorlist)
    #  Fetch mail
    mb = account.login()
    mail_list = pf.fetch_class(mb)

    log["mail_list count"] = len(mail_list)

    #  Build list of uids to move to defined folders
    whitelisted = [item.uid for item in mail_list if item.from_ in whitelist]
    blacklisted = [item.uid for item in mail_list if item.from_ in blacklist]
    vendorlist = [item.uid for item in mail_list if item.from_ in vendorlist]
    log["uids in whitelist"] = whitelisted
    log["uids in blacklist"] = blacklisted
    log["uids in vendorlist"] = vendorlist
    #  Move email using configured folder names
    config = get_config()
    account_config = None
    for acc in config.accounts:
        if acc.email == account.email:
            account_config = acc
            break
    
    if account_config and hasattr(account_config, 'folders'):
        processed_folder = account_config.folders.get('processed', 'INBOX.Processed')
        junk_folder = account_config.folders.get('junk', 'INBOX.Junk') 
        approved_ads_folder = account_config.folders.get('approved_ads', 'INBOX.Approved_Ads')
        pending_folder = account_config.folders.get('pending', 'INBOX.Pending')
    else:
        # Fallback to hardcoded names
        processed_folder = "INBOX.Processed"
        junk_folder = "INBOX.Junk"
        approved_ads_folder = "INBOX.Approved_Ads"
        pending_folder = "INBOX.Pending"
    
    mb.move(whitelisted, processed_folder)
    mb.move(blacklisted, junk_folder)
    mb.move(vendorlist, approved_ads_folder)
    
    # Apply retention policy to approved_ads folder after moving vendor emails
    if vendorlist:  # Only if we moved any vendor emails
        try:
            config = get_config()
            retention_days = config.get_retention_setting('approved_ads')
            if retention_days > 0:
                pf.purge_old(mb, approved_ads_folder, retention_days)
                log["vendor_retention_applied"] = f"Purged vendor emails older than {retention_days} days"
        except Exception as e:
            log["vendor_retention_error"] = f"Could not apply vendor retention policy: {str(e)}"

    if folder == "INBOX":
        #  Build list of uids to move to Pending folder
        pending = [item.uid for item in mail_list if item.from_ not in whitelist if item.from_ not in blacklist if
                   item.from_ not in vendorlist]
        log["uids in pending"] = pending

        mb.move(pending, pending_folder)
    else:
        pass

    return log

def process_inbox_maint(account, folder="INBOX", limit=500):
    """
    Fetches mail from specified server/account and folder.  Compares the from_ attribute against specified sender lists.
    If a sender matches an address in a specified list, message is dispositioned according to defined rules.  If no match,
    mail is sent to Pending folder.
    """
    # Process special rules
    for rule in r.rules_list:
        rule(account)

    mail_list = []
    log = {}
    log["process"] = "Process Inbox"
    # Load Lists using configuration
    whitelist = pf.open_read("white")
    blacklist = pf.open_read("black")
    vendorlist = pf.open_read("vendor")

    log["whitelist count"] = len(whitelist)
    log["blacklist count"] = len(blacklist)
    log["vendorlist count"] = len(vendorlist)
    #  Fetch mail
    mb = account.login()
    mail_list = pf.fetch_class(mb)

    log["mail_list count"] = len(mail_list)

    #  Build list of uids to move to defined folders
    whitelisted = [item.uid for item in mail_list if item.from_ in whitelist]
    blacklisted = [item.uid for item in mail_list if item.from_ in blacklist]
    vendorlist = [item.uid for item in mail_list if item.from_ in vendorlist]
    log["uids in whitelist"] = whitelisted
    log["uids in blacklist"] = blacklisted
    log["uids in vendorlist"] = vendorlist
    #  Move email using configured folder names
    config = get_config()
    account_config = None
    for acc in config.accounts:
        if acc.email == account.email:
            account_config = acc
            break
    
    if account_config and hasattr(account_config, 'folders'):
        junk_folder = account_config.folders.get('junk', 'INBOX.Junk') 
        approved_ads_folder = account_config.folders.get('approved_ads', 'INBOX.Approved_Ads')
        pending_folder = account_config.folders.get('pending', 'INBOX.Pending')
    else:
        # Fallback to hardcoded names
        junk_folder = "INBOX.Junk"
        approved_ads_folder = "INBOX.Approved_Ads"
        pending_folder = "INBOX.Pending"
    
    # In maintenance mode, don't move whitelisted emails to processed
    mb.move(blacklisted, junk_folder)
    mb.move(vendorlist, approved_ads_folder)
    
    # Apply retention policy to approved_ads folder after moving vendor emails
    if vendorlist:  # Only if we moved any vendor emails
        try:
            retention_days = config.get_retention_setting('approved_ads')
            if retention_days > 0:
                pf.purge_old(mb, approved_ads_folder, retention_days)
                log["vendor_retention_applied"] = f"Purged vendor emails older than {retention_days} days"
        except Exception as e:
            log["vendor_retention_error"] = f"Could not apply vendor retention policy: {str(e)}"

    if folder == "INBOX":
        #  Build list of uids to move to Pending folder
        pending = [item.uid for item in mail_list if item.from_ not in whitelist if item.from_ not in blacklist if
                   item.from_ not in vendorlist]
        log["uids in pending"] = pending

        mb.move(pending, pending_folder)
    else:
        pass

    return log
