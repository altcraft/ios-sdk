//
//  HAEventType.h
//  HiAnalytics
//
//  Created by cbg_bigdata on 2020/2/19.
//  Copyright © 2020 cbg_bigdata. All rights reserved.
//

#import <Foundation/Foundation.h>

// Event reported when a user has added payment information but has not initiated payment during check-out.It can be used with StartCheckout and CompletePurchase to construct funnel analysis for the check-out process.
static NSString *const kHAEventCreatePaymentInfo = @"$CreatePaymentInfo";

// Event reported when a user adds a product to the shopping cart.It can be used with ViewProduct and StartCheckout to construct funnel analysis for product purchase. It can also be used to analyze products that users are interested in, helping you promote the products to the users.
static NSString *const kHAEventAddProduct2Cart = @"$AddProduct2Cart";

// Event reported when a user adds a product to wishlist.It can be used to analyze products that users are interested in, helping you promote the products to the users.
static NSString *const kHAEventAddProduct2WishList = @"$AddProduct2WishList";

// Event reported when a user launches the app.
static NSString *const kHAEventStartApp = @"$StartApp";

// Event reported when a user clicks the check-out button after placing an order. It can be used with ViewProduct and CompletePurchase to construct funnel analysis for the e-commerce purchase conversion rate.
static NSString *const kHAEventStartCheckout = @"$StartCheckout";

// Event reported when a user views details of a marketing campaign. It can be used to analyze the conversion rate of a marketing campaign.
static NSString *const kHAEventViewCampaign = @"$ViewCampaign";

// Event reported after each step in the multi-step check-out process is completed. It can be used to analyze the conversion rate of each step in the check-out process, which helps you optimize the product design.
static NSString *const kHAEventViewCheckoutStep = @"$ViewCheckoutStep";

// Event reported when a user obtains virtual currency. It can be used to analyze the difficulty for users to obtain virtual currency, which helps you optimize the product design.
static NSString *const kHAEventWinVirtualCoin = @"$WinVirtualCoin";

// Event reported after a user purchases a product. It can be used to analyze the products or contents that users are more interested in, which helps you optimize the operations policy.
static NSString *const kHAEventCompletePurchase = @"$CompletePurchase";

// Event reported when a sales lead is obtained. For example, it can be reported after a user taps the ad you placed and fills in and submits the contact information. In this case, the event is used to evaluate the possible revenue brought by the lead to you. In addition, the event can also be used to evaluate the ROI of the placed ad.
static NSString *const kHAEventObtainLeads = @"$ObtainLeads";

// Event reported when a user joins in a group, for example, joining in a group chat in a social app. It can be used to evaluate the attractiveness of your product's social features to users.
static NSString *const kHAEventJoinUserGroup = @"$JoinUserGroup";

// Event reported when a user completes a game level in a game app. It can be used with StartLevel to analyze whether the game level design is proper and formulate targeted optimization policies.
static NSString *const kHAEventCompleteLevel = @"$CompleteLevel";

// Event reported when a user starts a game level in a game app.It can be used with CompleteLevel to analyze whether the game level design is proper and formulate targeted optimization policies.
static NSString *const kHAEventStartLevel = @"$StartLevel";

// Event reported when a user levels up in a game app. It can be used to analyze whether your product's user level design is optimal and formulate targeted optimization policies.
static NSString *const kHAEventUpgradeLevel = @"$UpgradeLevel";

// Event reported when a user signs in to an app requiring sign-in. It can be used to analyze users' sign-in habits and formulate targeted operations policies.
static NSString *const kHAEventSignIn = @"$SignIn";

//Event reported when a user signs in to an app requiring sign-out. It can be used to analyze users' sign-out habits and formulate targeted operations policies.
static NSString *const kHAEventSignOut = @"$SignOut";

// Event reported when a user submits the score in a game or education app. It can be used to analyze the difficulty of product content and formulate targeted optimization policies.
static NSString *const kHAEventSubmitScore = @"$SubmitScore";

// Event reported when the order details are displayed before check-out. It can be used with events such as ViewProduct and CompletePurchase to construct an analysis funnel for analyzing user churn in each phase and make optimization policies.
static NSString *const kHAEventCreateOrder = @"$CreateOrder";

// Event reported when the refund is successful for a user. It can be used to analyze loss caused by the refund and formulate targeted optimization policies.
static NSString *const kHAEventRefundOrder = @"$RefundOrder";

// Event reported when a user removes a product from the shopping cart. It can be used for targeted marketing to the user.
static NSString *const kHAEventDelProductFromCart = @"$DelProductFromCart";

// Event reported when a user searches for content in an app. It can be used with events such as ViewSearchResult and ViewProduct to analyze the accuracy of search results.
static NSString *const kHAEventSearch = @"$Search";

// Event reported when a user taps content, for example, tapping a product in the product list in an e-commerce app to view the product details. It can be used to analyze the products that users are interested in.
static NSString *const kHAEventViewContent = @"$ViewContent";

// Event reported when a user sets some check-out options during the check-out process. It can be used to analyze check-out preferences of users.
static NSString *const kHAEventUpdateCheckoutOption = @"$UpdateCheckoutOption";

// Event reported when a user shares a product or content through a social channel. It can be used to analyze users' loyalty to the product.
static NSString *const kHAEventShareContent = @"$ShareContent";

// Event reported when a user registers an account. It can be used to analyze the user sources and optimize operations policies.
static NSString *const kHAEventRegisterAccount = @"$RegisterAccount";

// Event reported when a user consumes virtual currency. It can be used to analyze the products that users are more interested in.
static NSString *const kHAEventConsumeVirtualCoin = @"$ConsumeVirtualCoin";

// Event reported when a user starts to use the tutorial. It can be used with CompleteTutorial to evaluate the tutorial quality and formulate targeted optimization policies.
static NSString *const kHAEventStartTutorial = @"$StartTutorial";

// Event reported when a user completes the tutorial. It can be used with StartTutorial to evaluate the tutorial quality and formulate targeted optimization policies.
static NSString *const kHAEventCompleteTutorial = @"$CompleteTutorial";

// Event reported when a user unlocks an achievement. It can be used to analyze whether the achievement level design is optimal and formulate targeted optimization policies.
static NSString *const kHAEventObtainAchievement = @"$ObtainAchievement";

// Event reported when a user browses a product. It can be used to analyze the products that users are interested in, or used with other events for funnel analysis.
static NSString *const kHAEventViewProduct = @"$ViewProduct";

// Event reported when a user browses a list of products, for example, browsing the list of products by category. It can be used to analyze the types of contents that users are more interested in.
static NSString *const kHAEventViewProductList = @"$ViewProductList";

// Event reported when a user views the search results. It can be used with ViewProduct and Search to measure the accuracy of the search algorithm.
static NSString *const kHAEventViewSearchResult = @"$ViewSearchResult";

// Event reported when a user purchases membership or signs in for the first time after membership expires. It can be used to analyze user habits.
static NSString *const kHAEventUpdateMembershipLevel = @"$UpdateMembershipLevel";

// Event reported when a user sets conditions to filter products displayed. It can be used to analyze user preferences.
static NSString *const kHAEventFiltrateProduct = @"$FiltrateProduct";

// Event reported when a user taps a product category. It can be used to analyze popular product categories or user preferences.
static NSString *const kHAEventViewCategory = @"$ViewCategory";

// Event reported when a user modifies an order.
static NSString *const kHAEventUpdateOrder = @"$UpdateOrder";

// Event reported when a user cancels an order.
static NSString *const kHAEventCancelOrder = @"$CancelOrder";

// Event reported when a user confirms the reception.
static NSString *const kHAEventCompleteOrder = @"$CompleteOrder";

// Event reported when a user cancels an ongoing payment of a submitted order. It can be used to analyze the cause of user churn.
static NSString *const kHAEventCancelCheckout = @"$CancelCheckout";

// Event reported when a user claims a voucher.
static NSString *const kHAEventObtainVoucher = @"$ObtainVoucher";

// Event reported when the quick start for a new user is opened.
static NSString *const kHAEventNoviceGuideStart = @"$NoviceGuideStart";

// Event reported when the quick start for a new user is closed.
static NSString *const kHAEventNoviceGuideEnd = @"$NoviceGuideEnd";

// Event reported when a game is started.
static NSString *const kHAEventStartGame = @"$StartGame";

// Event reported when a game is ended.
static NSString *const kHAEventEndGame = @"$EndGame";

// Event reported when props are added.
static NSString *const kHAEventWinProps = @"$WinProps";

// Event reported when props are consumed.
static NSString *const kHAEventConsumeProps = @"$ConsumeProps";

// Contact customer service.
static NSString *const kHAEventContactCustomService = @"$ContactCustomService";

// Rate product.
static NSString *const kHAEventRate = @"$Rate";

// Invite user.
static NSString *const kHAEventInvite = @"$Invite";

// Add friend
static NSString *const kHAEventAddFriend = @"$AddFriend";

// Add to blocklist
static NSString *const kHAEventAddBlacklist = @"$AddBlacklist";

// View friend list
static NSString *const kHAEventViewFriendList = @"$ViewFriendList";

// Leave group
static NSString *const kHAEventQuitUserGroup = @"$QuitUserGroup";

// Create group
static NSString *const kHAEventCreateUserGroup = @"$CreateUserGroup";

// Dismiss group
static NSString *const kHAEventDisbandUserGroup = @"$DisbandUserGroup";

// Upgrade group
static NSString *const kHAEventUpgradeUserGroup = @"$UpgradeUserGroup";

// Check group
static NSString *const kHAEventViewUserGroup = @"$ViewUserGroup";

// Join team
static NSString *const kHAEventJoinTeam = @"$JoinTeam";

// Send message
static NSString *const kHAEventSendMessage = @"$SendMessage";

// Learn skills
static NSString *const kHAEventLearnSkill = @"$LearnSkill";

// Use skills
static NSString *const kHAEventUseSkill = @"$UseSkill";

// Earn gear
static NSString *const kHAEventGetEquipment = @"$GetEquipment";

// Lose gear
static NSString *const kHAEventLoseEquipment = @"$LoseEquipment";

// Enhance gear
static NSString *const kHAEventEnhanceEquipment = @"$EnhanceEquipment";

// Change occupation
static NSString *const kHAEventSwitchClass = @"$SwitchClass";

// Undertake task
static NSString *const kHAEventAcceptTask = @"$AcceptTask";

// Complete task
static NSString *const kHAEventFinishTask = @"$FinishTask";

// Participate in activity
static NSString *const kHAEventAttendActivity = @"$AttendActivity";

// Complete cutscene
static NSString *const kHAEventFinishCutscene = @"$FinishCutscene";

// Skip cutscene
static NSString *const kHAEventSkipCutscene = @"$SkipCutscene";

// Earn pet
static NSString *const kHAEventGetPet = @"$GetPet";

// Lose pet
static NSString *const kHAEventLosePet = @"$LosePet";

// Upgrade pet
static NSString *const kHAEventEnhancePet = @"$EnhancePet";

// Earn mount
static NSString *const kHAEventGetMount = @"$GetMount";

// Lose mount
static NSString *const kHAEventLoseMount = @"$LoseMount";

// Upgrade mount
static NSString *const kHAEventEnhanceMount = @"$EnhanceMount";

// Create role
static NSString *const kHAEventCreateRole = @"$CreateRole";

// Sign in to role
static NSString *const kHAEventSignInRole = @"$SignInRole";

// Sign out of a role
static NSString *const kHAEventSignOutRole = @"$SignOutRole";

// Start battle
static NSString *const kHAEventStartBattle = @"$StartBattle";

// End battle
static NSString *const kHAEventEndBattle = @"$EndBattle";

// Enter dungeon
static NSString *const kHAEventStartDungeon = @"$StartDungeon";

// Clear dungeon
static NSString *const kHAEventFinishDungeon = @"$FinishDungeon";

// View package
static NSString *const kHAEventViewPackage = @"$ViewPackage";

// Use redemption code
static NSString *const kHAEventRedeem = @"$Redeem";

// Modify settings
static NSString *const kHAEventModifySetting = @"$ModifySetting";

// Watch video
static NSString *const kHAEventWatchVideo = @"$WatchVideo";

// Tap message
static NSString *const kHAEventClickMessage = @"$ClickMessage";

// Pull card
static NSString *const kHAEventDrawCard = @"$DrawCard";

// View card list
static NSString *const kHAEventViewCardList = @"$ViewCardList";

// Bind account
static NSString *const kHAEventBindAccount = @"$BindAccount";

// Start practicing
static NSString *const kHAEventStartExercise = @"$StartExercise";

// Stop practicing
static NSString *const kHAEventEndExercise = @"$EndExercise";

// Start playback
static NSString *const kHAEventStartPlayMedia = @"$StartPlayMedia";

// Stop playback
static NSString *const kHAEventEndPlayMedia = @"$EndPlayMedia";

// Start exam
static NSString *const kHAEventStartExamine = @"$StartExamine";

// Stop exam
static NSString *const kHAEventEndExamine = @"$EndExamine";

// Check in
static NSString *const kHAEventCheckIn = @"$CheckIn";

// Post
static NSString *const kHAEventPost = @"$Post";

// Share App
static NSString *const kHAEventShareApp = @"$ShareApp";

// Complete information
static NSString *const kHAEventImproveInformation = @"$ImproveInformation";

// Request compensation
static NSString *const kHAEventCompensation = @"$Compensation";

// View house list
static NSString *const kHAEventViewHouseList = @"$ViewHouseList";

// View house detail
static NSString *const kHAEventViewHouseDetail = @"$ViewHouseDetail";

// Exchange goods
static NSString *const kHAEventExchangeGoods = @"$ExchangeGoods";

// Binding device
static NSString *const kHAEventBindDevice = @"$BindDevice";

// Unbinding device
static NSString *const kHAEventUnBindDevice = @"$UnBindDevice";

// Appointment maintenance
static NSString *const kHAEventReserveMaintenance = @"$ReserveMaintenance";

// Loss reporting device
static NSString *const kHAEventDeviceMissingReport = @"$DeviceMissingReport";

 // Start booking
static NSString *const kHAEventStartBooking = @"$StartBooking";

 // Learning objectives
static NSString *const kHAEventLearnTarget = @"$LearnTarget";

 // Language proficiency test
static NSString *const kHAEventLanguageTest = @"$LanguageTest";

 // Start moving
static NSString *const kHAEventStartTraining = @"$StartTraining";

 // End movement
static NSString *const kHAEventEndTraining = @"$EndTraining";

 // Registration activities
static NSString *const kHAEventRegisterActivity = @"$RegisterActivity";

 // Exit activity
static NSString *const kHAEventExitActivity = @"$ExitActivity";

 // Complete the activity
static NSString *const kHAEventCompleteActivity = @"$CompleteActivity";

 // Focus on content
static NSString *const kHAEventFollowContent = @"$FollowContent";

 // Triggered when the ID card scanning result is returned during user account opening
static NSString *const kHAEventEnterAccountOpening = @"$EnterAccountOpening";

 // Account opening submission
static NSString *const kHAEventSubmitAccountOpening = @"$SubmitAccountOpening";

 // Triggered when the user's card binding is completed
static NSString *const kHAEventBandCard = @"$BandCard";

 // Triggered when the user's transfer in is completed
static NSString *const kHAEventBankTransferIn = @"$BankTransferIn";

 // Triggered when the user's transfer out is completed
static NSString *const kHAEventBankTransferOut = @"$BankTransferOut";

 // Report to the front when entering the individual stock details page
static NSString *const kHAEventViewStockDetail = @"$ViewStockDetail";

 // Stock transaction completion trigger
static NSString *const kHAEventTradeStocks = @"$TradeStocks";

 // Triggered when the user browses the financial product details page
static NSString *const kHAEventViewFinancePage = @"$ViewFinancePage";

 // Triggered when the user successfully purchases financial products
static NSString *const kHAEventPurchaseFinance = @"$PurchaseFinance";

 // Triggered when a user submits a redemption application for a financial product
static NSString *const kHAEventRedemptionFinance = @"$RedemptionFinance";

 // Fund transaction completion trigger
static NSString *const kHAEventFundTrading = @"$FundTrading";

 // Triggered when setting fixed investment
static NSString *const kHAEventFixedinvestment = @"$Fixedinvestment";

 // Subscription of new shares and / or bonds
static NSString *const kHAEventApplyNew = @"$ApplyNew";

 // Triggered when browsing information
static NSString *const kHAEventViewInformationSection = @"$ViewInformationSection";

 // For details, please refer to the consultation information
static NSString *const kHAEventViewInformation = @"$ViewInformation";

// Function button click
static NSString *const kHAEventModularClick = @"$ModularClick";

// Page browsing
static NSString *const kHAEventPageView = @"$PageView";

// Coupon exposure
static NSString *const kHAEventDisplayVoucher = @"$DisplayVoucher";

// Book a course
static NSString *const kHAEventBookCourse = @"$BookCourse";

// Study course
static NSString *const kHAEventLearnCourses = @"$LearnCourses";

// Audition course
static NSString *const kHAEventTryout = @"$Tryout";

// CommentContent
static NSString *const kHAEventCommentContent = @"$CommentContent";

// give the thumbs-up
static NSString *const kHAEventLikeContent = @"$LikeContent";

// DeleteProduct2WishList
static NSString *const kHAEventDeleteProduct2WishList = @"$DeleteProduct2WishList";

// Ad Click
static NSString *const kHAEventAdClick = @"$AdClick";

// Advertising display
static NSString *const kHAEventAdDisplay = @"$AdDisplay";

// Open member
static NSString *const kHAEventEnableMember = @"$EnableMember";

// Cancel membership
static NSString *const kHAEventCancelMember = @"$CancelMember";

// Pay per click
static NSString *const kHAEventClickPurchase = @"$ClickPurchase";

// ViewFundPage
static NSString *const kHAEventViewFundPage = @"$ViewFundPage";

// Answer
static NSString *const kHAEventAnswer = @"$Answer";

// VipSuc
static NSString *const kHAEventVipSuc = @"$VipSuc";

// RegisterFailed
static NSString *const kHAEventRegisterFailed = @"$RegisterFailed";

// VipClick
static NSString *const kHAEventVipClick = @"$VipClick";

// VipFailed
static NSString *const kHAEventVipFailed = @"$VipFailed";
