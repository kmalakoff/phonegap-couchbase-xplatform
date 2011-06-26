package com.couchbaseextensions;

import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.content.ServiceConnection;
import android.util.Log;

import com.couchbase.libcouch.CouchDB;
import com.couchbase.libcouch.ICouchClient;
    
public class CouchStarter
{
	public interface CouchStarterCallback 
	{ 
		public void couchStarted(String host, int port); 
		public void failed(); 
	}
	
  private android.app.Activity owningActivity;
  private CouchStarterCallback starterCallback;
  private ServiceConnection couchServiceConnection;

  protected static final String release = "release-0.1";
  protected static final String LOG_TAG = "CouchStarter";

  public CouchStarter(android.app.Activity inOwningActivity, CouchStarterCallback inStarterCallback)
  {
    owningActivity = inOwningActivity;
    starterCallback = inStarterCallback;
    couchServiceConnection = null;
  }
	
  public void startCouch() 
  {
    // already started
    if(couchServiceConnection!=null)
    {
      Log.v(LOG_TAG, "Cannot start Couchbase: it is already starting or started");
      return;
    }
		
    ICouchClient callback = new ICouchClient.Stub() 
    {
      private ProgressDialog installProgress = null;

      @Override
      public final void couchStarted(String host, int port) 
      {
        if (installProgress != null) 
        installProgress.dismiss();

        starterCallback.couchStarted(host, port);
      }

      @Override
      public void installing(int completed, int total) 
      {
        ensureProgressDialog();
        installProgress.setTitle("Initialising CouchDB");
        installProgress.setProgress(completed);
        installProgress.setMax(total);
      }

      @Override
      public void exit(String error) 
      {
        Log.v(LOG_TAG, error);
        couchError();
      }

      private void ensureProgressDialog() 
      {
        if (installProgress == null) 
        {
          installProgress = new ProgressDialog(owningActivity);
          installProgress.setTitle(" ");
          installProgress.setCancelable(false);
          installProgress.setProgressStyle(ProgressDialog.STYLE_HORIZONTAL);
          installProgress.show();
        }
      }

      private void couchError() 
      {
        AlertDialog.Builder builder = new AlertDialog.Builder(owningActivity);
        builder.setMessage("Error").setPositiveButton("Try Again?",
          new DialogInterface.OnClickListener() 
          {
            @Override
            public void onClick(DialogInterface dialog, int id) { startCouch(); }
          })
          .setNegativeButton("Cancel",
          new DialogInterface.OnClickListener() 
          {
            @Override
            public void onClick(DialogInterface dialog, int id) { owningActivity.moveTaskToBack(true); }
          }
        );
        AlertDialog alert = builder.create();
        alert.show();
      }
  };

   couchServiceConnection = CouchDB.getService(owningActivity, null, release, callback);
  }

  public void stopCouch()
  {
    if(couchServiceConnection==null)
    {
      Log.v(LOG_TAG, "Cannot stop Couchbase: it is not running");
      return;
    }   			

    owningActivity.unbindService(couchServiceConnection);
    couchServiceConnection = null;
  }
}
    
