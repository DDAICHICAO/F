abstract class ApiPaths {
  // passport (auth)
  static const login = '/passport/auth/login';
  static const register = '/passport/auth/register';
  static const forget = '/passport/auth/forget';
  static const token2Login = '/passport/auth/token2Login';
  static const getQuickLoginUrl = '/passport/auth/getQuickLoginUrl';
  static const sendEmailVerify = '/passport/comm/sendEmailVerify';
  static const pv = '/passport/comm/pv';

  // guest
  static const guestConfig = '/guest/comm/config';

  // user
  static const userInfo = '/user/info';
  static const userStat = '/user/getStat';
  static const userSubscribe = '/user/getSubscribe';
  static const userCheckLogin = '/user/checkLogin';
  static const userChangePassword = '/user/changePassword';
  static const userUpdate = '/user/update';
  static const userResetSecurity = '/user/resetSecurity';
  static const userSignedSubscribeUrl = '/user/getSignedSubscribeUrl';
  static const userActiveSession = '/user/getActiveSession';
  static const userRemoveActiveSession = '/user/removeActiveSession';
  static const userTransfer = '/user/transfer';
  static const userRedeemgiftcard = '/user/redeemgiftcard';
  static const userCompensateLogs = '/user/compensateLogs';
  static const userSubscribeSecurityInfo = '/user/subscribeSecurity/info';
  static const userSubscribeSecurityRequestUnban =
      '/user/subscribeSecurity/requestUnban';

  // user/comm
  static const userCommConfig = '/user/comm/config';
  static const userStripePublicKey = '/user/comm/getStripePublicKey';

  // plan
  static const planFetch = '/user/plan/fetch';

  // order
  static const orderSave = '/user/order/save';
  static const orderPreview = '/user/order/preview';
  static const orderCheckout = '/user/order/checkout';
  static const orderCheck = '/user/order/check';
  static const orderDetail = '/user/order/detail';
  static const orderFetch = '/user/order/fetch';
  static const orderCancel = '/user/order/cancel';
  static const orderPaymentMethod = '/user/order/getPaymentMethod';
  static const orderRechargeInfo = '/user/order/rechargeInfo';

  // coupon
  static const couponCheck = '/user/coupon/check';
  static const couponAvailable = '/user/coupon/getAvailableCoupons';

  // ticket
  static const ticketFetch = '/user/ticket/fetch';
  static const ticketSave = '/user/ticket/save';
  static const ticketReply = '/user/ticket/reply';
  static const ticketClose = '/user/ticket/close';
  static const ticketUpload = '/user/ticket/upload';
  static const ticketWithdraw = '/user/ticket/withdraw';

  // notice
  static const noticeFetch = '/user/notice/fetch';

  // invite
  static const inviteSave = '/user/invite/save';
  static const inviteFetch = '/user/invite/fetch';
  static const inviteDetails = '/user/invite/details';
  static const inviteDrop = '/user/invite/drop';

  // server
  static const serverFetch = '/user/server/fetch';

  // knowledge
  static const knowledgeFetch = '/user/knowledge/fetch';
  static const knowledgeCategory = '/user/knowledge/getCategory';

  // stat
  static const statTrafficLog = '/user/stat/getTrafficLog';
  static const statNodeTrafficLog = '/user/stat/getNodeTrafficLog';
  static const statSubscribeLog = '/user/stat/getSubscribeLog';
  static const statAliveIpLog = '/user/stat/getAliveIpLog';
  static const statSubscribeStat = '/user/stat/getSubscribeStat';

  // client
  static const clientAppConfig = '/client/app/getConfig';
  static const clientAppVersion = '/client/app/getVersion';
}
