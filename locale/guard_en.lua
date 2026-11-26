local _, ns = ...
local L = ns.locales.enUS
L.guardNoticeKeys = "Database near the client load limit: ~%d {constant|constants} of %d, details in Settings"
L.guardFile = "If the client failed to read a large file, it is still on disk: before logging out or reloading the interface, copy WTF\\Account\\<account>\\SavedVariables\\ManaCode_AuctionScan.lua elsewhere; on logout the client writes the empty database over it."
L.guardNoticeLost = "Database lost, copy from %s exists: choose in Settings"
