/*
 * This file is auto-generated.  DO NOT MODIFY.
 * Original file: /Users/kevin/Dev/phonegap-couchbase-xplatform/libcouch-android/src/com/couchbase/libcouch/ICouchClient.aidl
 */
package com.couchbase.libcouch;
public interface ICouchClient extends android.os.IInterface
{
/** Local-side IPC implementation stub class. */
public static abstract class Stub extends android.os.Binder implements com.couchbase.libcouch.ICouchClient
{
private static final java.lang.String DESCRIPTOR = "com.couchbase.libcouch.ICouchClient";
/** Construct the stub at attach it to the interface. */
public Stub()
{
this.attachInterface(this, DESCRIPTOR);
}
/**
 * Cast an IBinder object into an com.couchbase.libcouch.ICouchClient interface,
 * generating a proxy if needed.
 */
public static com.couchbase.libcouch.ICouchClient asInterface(android.os.IBinder obj)
{
if ((obj==null)) {
return null;
}
android.os.IInterface iin = (android.os.IInterface)obj.queryLocalInterface(DESCRIPTOR);
if (((iin!=null)&&(iin instanceof com.couchbase.libcouch.ICouchClient))) {
return ((com.couchbase.libcouch.ICouchClient)iin);
}
return new com.couchbase.libcouch.ICouchClient.Stub.Proxy(obj);
}
public android.os.IBinder asBinder()
{
return this;
}
@Override public boolean onTransact(int code, android.os.Parcel data, android.os.Parcel reply, int flags) throws android.os.RemoteException
{
switch (code)
{
case INTERFACE_TRANSACTION:
{
reply.writeString(DESCRIPTOR);
return true;
}
case TRANSACTION_couchStarted:
{
data.enforceInterface(DESCRIPTOR);
java.lang.String _arg0;
_arg0 = data.readString();
int _arg1;
_arg1 = data.readInt();
this.couchStarted(_arg0, _arg1);
reply.writeNoException();
return true;
}
case TRANSACTION_installing:
{
data.enforceInterface(DESCRIPTOR);
int _arg0;
_arg0 = data.readInt();
int _arg1;
_arg1 = data.readInt();
this.installing(_arg0, _arg1);
reply.writeNoException();
return true;
}
case TRANSACTION_exit:
{
data.enforceInterface(DESCRIPTOR);
java.lang.String _arg0;
_arg0 = data.readString();
this.exit(_arg0);
reply.writeNoException();
return true;
}
}
return super.onTransact(code, data, reply, flags);
}
private static class Proxy implements com.couchbase.libcouch.ICouchClient
{
private android.os.IBinder mRemote;
Proxy(android.os.IBinder remote)
{
mRemote = remote;
}
public android.os.IBinder asBinder()
{
return mRemote;
}
public java.lang.String getInterfaceDescriptor()
{
return DESCRIPTOR;
}
/* Callback to notify when CouchDB has started */
public void couchStarted(java.lang.String host, int port) throws android.os.RemoteException
{
android.os.Parcel _data = android.os.Parcel.obtain();
android.os.Parcel _reply = android.os.Parcel.obtain();
try {
_data.writeInterfaceToken(DESCRIPTOR);
_data.writeString(host);
_data.writeInt(port);
mRemote.transact(Stub.TRANSACTION_couchStarted, _data, _reply, 0);
_reply.readException();
}
finally {
_reply.recycle();
_data.recycle();
}
}
/* Callback for notifications on how the CouchDB install is progressing */
public void installing(int completed, int total) throws android.os.RemoteException
{
android.os.Parcel _data = android.os.Parcel.obtain();
android.os.Parcel _reply = android.os.Parcel.obtain();
try {
_data.writeInterfaceToken(DESCRIPTOR);
_data.writeInt(completed);
_data.writeInt(total);
mRemote.transact(Stub.TRANSACTION_installing, _data, _reply, 0);
_reply.readException();
}
finally {
_reply.recycle();
_data.recycle();
}
}
public void exit(java.lang.String error) throws android.os.RemoteException
{
android.os.Parcel _data = android.os.Parcel.obtain();
android.os.Parcel _reply = android.os.Parcel.obtain();
try {
_data.writeInterfaceToken(DESCRIPTOR);
_data.writeString(error);
mRemote.transact(Stub.TRANSACTION_exit, _data, _reply, 0);
_reply.readException();
}
finally {
_reply.recycle();
_data.recycle();
}
}
}
static final int TRANSACTION_couchStarted = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
static final int TRANSACTION_installing = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);
static final int TRANSACTION_exit = (android.os.IBinder.FIRST_CALL_TRANSACTION + 2);
}
/* Callback to notify when CouchDB has started */
public void couchStarted(java.lang.String host, int port) throws android.os.RemoteException;
/* Callback for notifications on how the CouchDB install is progressing */
public void installing(int completed, int total) throws android.os.RemoteException;
public void exit(java.lang.String error) throws android.os.RemoteException;
}
