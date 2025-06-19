"""
Rules Engine for Mail-Rulez

Provides flexible rule-based email processing with conditions and actions.
Supports sender-based, subject-based, and content-based rules.
"""

import json
import re
from pathlib import Path
from typing import List, Dict, Any, Optional, Union
from dataclasses import dataclass, asdict
from enum import Enum


class ConditionType(Enum):
    """Types of rule conditions"""
    SENDER_CONTAINS = "sender_contains"
    SENDER_DOMAIN = "sender_domain"
    SENDER_EXACT = "sender_exact"
    SUBJECT_CONTAINS = "subject_contains"
    SUBJECT_EXACT = "subject_exact"
    SUBJECT_REGEX = "subject_regex"
    CONTENT_CONTAINS = "content_contains"


class ActionType(Enum):
    """Types of rule actions"""
    MOVE_TO_FOLDER = "move_to_folder"
    ADD_TO_LIST = "add_to_list"
    CREATE_LIST = "create_list"
    FORWARD = "forward"
    MARK_READ = "mark_read"


@dataclass
class RuleCondition:
    """A single condition in a rule"""
    type: ConditionType
    value: str
    case_sensitive: bool = False
    
    def matches(self, email_data: Dict[str, Any]) -> bool:
        """Check if this condition matches the email data"""
        if self.type == ConditionType.SENDER_CONTAINS:
            sender = email_data.get('from', '').lower() if not self.case_sensitive else email_data.get('from', '')
            value = self.value.lower() if not self.case_sensitive else self.value
            return value in sender
            
        elif self.type == ConditionType.SENDER_DOMAIN:
            sender = email_data.get('from', '')
            # Extract domain from email address
            if '@' in sender:
                domain = sender.split('@')[-1].strip('>')
                return domain.lower() == self.value.lower()
            return False
            
        elif self.type == ConditionType.SENDER_EXACT:
            sender = email_data.get('from', '')
            if not self.case_sensitive:
                return sender.lower() == self.value.lower()
            return sender == self.value
            
        elif self.type == ConditionType.SUBJECT_CONTAINS:
            subject = email_data.get('subject', '').lower() if not self.case_sensitive else email_data.get('subject', '')
            value = self.value.lower() if not self.case_sensitive else self.value
            return value in subject
            
        elif self.type == ConditionType.SUBJECT_EXACT:
            subject = email_data.get('subject', '')
            if not self.case_sensitive:
                return subject.lower() == self.value.lower()
            return subject == self.value
            
        elif self.type == ConditionType.SUBJECT_REGEX:
            subject = email_data.get('subject', '')
            flags = 0 if self.case_sensitive else re.IGNORECASE
            try:
                return bool(re.search(self.value, subject, flags))
            except re.error:
                return False
                
        elif self.type == ConditionType.CONTENT_CONTAINS:
            content = email_data.get('content', '').lower() if not self.case_sensitive else email_data.get('content', '')
            value = self.value.lower() if not self.case_sensitive else self.value
            return value in content
            
        return False


@dataclass
class RuleAction:
    """A single action in a rule"""
    type: ActionType
    target: str
    parameters: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.parameters is None:
            self.parameters = {}


@dataclass
class EmailRule:
    """A complete email processing rule"""
    id: str
    name: str
    description: str
    conditions: List[RuleCondition]
    actions: List[RuleAction]
    account_email: str = ""  # Email account this rule applies to
    condition_logic: str = "AND"  # "AND" or "OR"
    active: bool = True
    priority: int = 100
    created_at: str = ""
    updated_at: str = ""
    
    def matches(self, email_data: Dict[str, Any]) -> bool:
        """Check if this rule matches the given email data"""
        if not self.active or not self.conditions:
            return False
            
        if self.condition_logic == "AND":
            return all(condition.matches(email_data) for condition in self.conditions)
        elif self.condition_logic == "OR":
            return any(condition.matches(email_data) for condition in self.conditions)
        else:
            # Default to AND logic
            return all(condition.matches(email_data) for condition in self.conditions)


class RulesEngine:
    """Main rules engine for processing emails"""
    
    def __init__(self, rules_file: Path = None):
        self.rules_file = rules_file or Path("rules.json")
        self.rules: List[EmailRule] = []
        self.load_rules()
    
    def load_rules(self):
        """Load rules from the rules file"""
        if not self.rules_file.exists():
            self.rules = []
            return
            
        try:
            with open(self.rules_file, 'r') as f:
                rules_data = json.load(f)
                
            self.rules = []
            for rule_data in rules_data:
                # Convert conditions
                conditions = []
                for cond_data in rule_data.get('conditions', []):
                    conditions.append(RuleCondition(
                        type=ConditionType(cond_data['type']),
                        value=cond_data['value'],
                        case_sensitive=cond_data.get('case_sensitive', False)
                    ))
                
                # Convert actions
                actions = []
                for action_data in rule_data.get('actions', []):
                    actions.append(RuleAction(
                        type=ActionType(action_data['type']),
                        target=action_data['target'],
                        parameters=action_data.get('parameters', {})
                    ))
                
                # Create rule
                rule = EmailRule(
                    id=rule_data['id'],
                    name=rule_data['name'],
                    description=rule_data['description'],
                    conditions=conditions,
                    actions=actions,
                    condition_logic=rule_data.get('condition_logic', 'AND'),
                    active=rule_data.get('active', True),
                    priority=rule_data.get('priority', 100),
                    created_at=rule_data.get('created_at', ''),
                    updated_at=rule_data.get('updated_at', '')
                )
                
                self.rules.append(rule)
                
        except (json.JSONDecodeError, KeyError, ValueError) as e:
            print(f"Error loading rules: {e}")
            self.rules = []
    
    def save_rules(self):
        """Save rules to the rules file"""
        rules_data = []
        for rule in self.rules:
            rule_dict = asdict(rule)
            # Convert enums to strings
            for condition in rule_dict['conditions']:
                condition['type'] = condition['type'].value
            for action in rule_dict['actions']:
                action['type'] = action['type'].value
            rules_data.append(rule_dict)
            
        with open(self.rules_file, 'w') as f:
            json.dump(rules_data, f, indent=2)
    
    def add_rule(self, rule: EmailRule):
        """Add a new rule"""
        self.rules.append(rule)
        self.rules.sort(key=lambda r: r.priority)
        self.save_rules()
    
    def update_rule(self, rule_id: str, updated_rule: EmailRule):
        """Update an existing rule"""
        for i, rule in enumerate(self.rules):
            if rule.id == rule_id:
                self.rules[i] = updated_rule
                self.rules.sort(key=lambda r: r.priority)
                self.save_rules()
                return True
        return False
    
    def delete_rule(self, rule_id: str):
        """Delete a rule"""
        self.rules = [rule for rule in self.rules if rule.id != rule_id]
        self.save_rules()
    
    def get_rule(self, rule_id: str) -> Optional[EmailRule]:
        """Get a rule by ID"""
        for rule in self.rules:
            if rule.id == rule_id:
                return rule
        return None
    
    def get_all_rules(self) -> List[EmailRule]:
        """Get all rules, sorted by priority"""
        return sorted(self.rules, key=lambda r: r.priority)
    
    def process_email(self, email_data: Dict[str, Any]) -> List[RuleAction]:
        """Process an email through all rules and return matching actions"""
        matching_actions = []
        
        for rule in self.get_all_rules():
            if rule.matches(email_data):
                matching_actions.extend(rule.actions)
                
        return matching_actions


# Pre-built rule templates
RULE_TEMPLATES = {
    "package_delivery": {
        "name": "Package Delivery",
        "description": "Automatically organize package delivery notifications",
        "conditions": [
            {
                "type": ConditionType.SENDER_DOMAIN,
                "value": "fedex.com",
                "case_sensitive": False
            },
            {
                "type": ConditionType.SENDER_DOMAIN,
                "value": "ups.com",
                "case_sensitive": False
            },
            {
                "type": ConditionType.SENDER_DOMAIN,
                "value": "usps.com",
                "case_sensitive": False
            },
            {
                "type": ConditionType.SENDER_DOMAIN,
                "value": "amazon.com",
                "case_sensitive": False
            },
            {
                "type": ConditionType.SENDER_DOMAIN,
                "value": "dhl.com",
                "case_sensitive": False
            }
        ],
        "actions": [
            {
                "type": ActionType.MOVE_TO_FOLDER,
                "target": "INBOX.Packages"
            },
            {
                "type": ActionType.ADD_TO_LIST,
                "target": "packages.txt"
            }
        ],
        "condition_logic": "OR",
        "priority": 50
    },
    
    "receipts_invoices": {
        "name": "Receipts & Invoices",
        "description": "Organize financial documents and receipts",
        "conditions": [
            {
                "type": ConditionType.SUBJECT_CONTAINS,
                "value": "invoice",
                "case_sensitive": False
            },
            {
                "type": ConditionType.SUBJECT_CONTAINS,
                "value": "receipt",
                "case_sensitive": False
            },
            {
                "type": ConditionType.SUBJECT_CONTAINS,
                "value": "bill",
                "case_sensitive": False
            },
            {
                "type": ConditionType.SUBJECT_CONTAINS,
                "value": "statement",
                "case_sensitive": False
            },
            {
                "type": ConditionType.SUBJECT_CONTAINS,
                "value": "payment",
                "case_sensitive": False
            }
        ],
        "actions": [
            {
                "type": ActionType.MOVE_TO_FOLDER,
                "target": "INBOX.Receipts"
            },
            {
                "type": ActionType.ADD_TO_LIST,
                "target": "receipts.txt"
            }
        ],
        "condition_logic": "OR",
        "priority": 60
    },
    
    "linkedin": {
        "name": "LinkedIn Notifications",
        "description": "Organize LinkedIn professional networking emails",
        "conditions": [
            {
                "type": ConditionType.SENDER_DOMAIN,
                "value": "linkedin.com",
                "case_sensitive": False
            }
        ],
        "actions": [
            {
                "type": ActionType.MOVE_TO_FOLDER,
                "target": "INBOX.LinkedIn"
            },
            {
                "type": ActionType.ADD_TO_LIST,
                "target": "linkedin.txt"
            }
        ],
        "condition_logic": "AND",
        "priority": 70
    },
    
    "head_hunter": {
        "name": "Head Hunter Recruiters - Training Only", 
        "description": "Training folder rule for headhunter emails. Adds sender to head list and moves to HeadHunt folder. Use training folder INBOX._headhunter for manual categorization.",
        "conditions": [],
        "actions": [
            {
                "type": ActionType.ADD_TO_LIST,
                "target": "head.txt"
            },
            {
                "type": ActionType.MOVE_TO_FOLDER,
                "target": "INBOX.HeadHunt"
            }
        ],
        "condition_logic": "AND",
        "priority": 80
    }
}


def create_rule_from_template(template_name: str, rule_id: str) -> Optional[EmailRule]:
    """Create a rule from a pre-built template"""
    if template_name not in RULE_TEMPLATES:
        return None
        
    template = RULE_TEMPLATES[template_name]
    
    # Convert template conditions
    conditions = []
    for cond_data in template['conditions']:
        conditions.append(RuleCondition(
            type=cond_data['type'],
            value=cond_data['value'],
            case_sensitive=cond_data.get('case_sensitive', False)
        ))
    
    # Convert template actions
    actions = []
    for action_data in template['actions']:
        actions.append(RuleAction(
            type=action_data['type'],
            target=action_data['target'],
            parameters=action_data.get('parameters', {})
        ))
    
    return EmailRule(
        id=rule_id,
        name=template['name'],
        description=template['description'],
        conditions=conditions,
        actions=actions,
        condition_logic=template.get('condition_logic', 'AND'),
        priority=template.get('priority', 100),
        active=True
    )


def load_active_rules_for_account(account_email: str) -> List[EmailRule]:
    """
    Load active rules for a specific account
    
    Args:
        account_email: Email address of the account
        
    Returns:
        list: List of active Rule objects for the account
    """
    try:
        manager = RulesEngine()
        rules = manager.get_all_rules()
        
        # Filter for active rules that apply to this account or all accounts (empty account_email)
        active_rules = [
            rule for rule in rules 
            if rule.active and (rule.account_email == account_email or rule.account_email == "")
        ]
        
        return active_rules
        
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Failed to load active rules for account {account_email}: {e}")
        return []


# Backward compatibility for old rules system
# The old system used @rule decorators and rules_list
# For now, provide an empty list to prevent crashes
rules_list = []