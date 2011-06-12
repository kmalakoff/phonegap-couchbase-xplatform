%% Generated by the Erlang ASN.1 compiler version:1.4.4.8
%% Purpose: Erlang record definitions for each named and unnamed
%% SEQUENCE and SET, and macro definitions for each value
%% definition,in module PKIXAttributeCertificate



-record('AttributeCertificate',{
acinfo, signatureAlgorithm, signatureValue}).

-record('AttributeCertificateInfo',{
version, holder, issuer, signature, serialNumber, attrCertValidityPeriod, attributes, issuerUniqueID = asn1_NOVALUE, extensions = asn1_NOVALUE}).

-record('Holder',{
baseCertificateID = asn1_NOVALUE, entityName = asn1_NOVALUE, objectDigestInfo = asn1_NOVALUE}).

-record('ObjectDigestInfo',{
digestedObjectType, otherObjectTypeID = asn1_NOVALUE, digestAlgorithm, objectDigest}).

-record('V2Form',{
issuerName = asn1_NOVALUE, baseCertificateID = asn1_NOVALUE, objectDigestInfo = asn1_NOVALUE}).

-record('IssuerSerial',{
issuer, serial, issuerUID = asn1_NOVALUE}).

-record('AttCertValidityPeriod',{
notBeforeTime, notAfterTime}).

-record('TargetCert',{
targetCertificate, targetName = asn1_NOVALUE, certDigestInfo = asn1_NOVALUE}).

-record('IetfAttrSyntax',{
policyAuthority = asn1_NOVALUE, values}).

-record('SvceAuthInfo',{
service, ident, authInfo = asn1_NOVALUE}).

-record('RoleSyntax',{
roleAuthority = asn1_NOVALUE, roleName}).

-record('Clearance',{
policyId, classList = asn1_DEFAULT, securityCategories = asn1_NOVALUE}).

-record('SecurityCategory',{
type, value}).

-record('AAControls',{
pathLenConstraint = asn1_NOVALUE, permittedAttrs = asn1_NOVALUE, excludedAttrs = asn1_NOVALUE, permitUnSpecified = asn1_DEFAULT}).

-record('ACClearAttrs',{
acIssuer, acSerial, attrs}).

-define('id-pe-ac-auditIdentity', {1,3,6,1,5,5,7,1,4}).
-define('id-pe-aaControls', {1,3,6,1,5,5,7,1,6}).
-define('id-pe-ac-proxying', {1,3,6,1,5,5,7,1,10}).
-define('id-ce-targetInformation', {2,5,29,55}).
-define('id-aca', {1,3,6,1,5,5,7,10}).
-define('id-aca-authenticationInfo', {1,3,6,1,5,5,7,10,1}).
-define('id-aca-accessIdentity', {1,3,6,1,5,5,7,10,2}).
-define('id-aca-chargingIdentity', {1,3,6,1,5,5,7,10,3}).
-define('id-aca-group', {1,3,6,1,5,5,7,10,4}).
-define('id-aca-encAttrs', {1,3,6,1,5,5,7,10,6}).
-define('id-at-role', {2,5,4,72}).
-define('id-at-clearance', {2,5,1,5,55}).
