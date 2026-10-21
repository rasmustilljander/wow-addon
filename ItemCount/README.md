# ItemCount

Adds lines to item tooltips showing how many of the item each of your characters has, and where:

```
Linen Cloth
Total     75
Rasmus    60 (bags 20, bank 40)
Altie     15 (bags 10, AH 5)
```

Names are in class colors, this character first, then whoever has the most. Characters on other realms show as `Name-Realm`. **Total** only shows when more than one character (or the account bank) has the item.

## What's counted

| Place | Counted |
| --- | --- |
| `bags` | Bags, reagent bag and keyring, whenever they change |
| `equipped` | Worn items, whenever they change |
| `bank` | Bank tabs, while the bank is open |
| `mail` | The inbox while the mailbox is open, plus items you mail to your own characters as soon as they're sent |
| `AH` | Your active auctions, when you open the auction house and after posting or canceling |
| Account bank | Its own line, while the bank is open (if the account bank is available) |

Bank, mail and AH counts are from your last visit with that character, so log in each character and visit them once. Auctions stop counting when their time runs out. Sales made while you're away still count until your next AH visit. COD mail and currencies aren't counted, and neither is mail the client hasn't loaded yet in an overfull inbox.

## Commands

| | |
| --- | --- |
| `/itemcount` | When each character's bank, mail and AH were last counted |
| `/itemcount forget <name>` | Drop a deleted character (`Name` or `Name-Realm`) |

## Saved data

`ItemCountDB` (account-wide):

| Field | |
| --- | --- |
| `chars["Name-Realm"]` | `class`; `bags`, `equipped`, `bank`, `mail` as item ID → count; `auctions` as `{ id, count, ends }` lists; `bankTime`, `mailTime`, `auctionTime` (nil until first counted) |
| `accountBank`, `accountBankTime` | The account bank's item ID → count, and when it was counted |
