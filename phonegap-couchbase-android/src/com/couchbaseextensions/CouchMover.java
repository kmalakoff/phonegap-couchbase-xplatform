
package com.couchbaseextensions;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.PasswordAuthentication;
import java.net.URL;
import java.util.List;
import java.util.Map;
import java.util.Scanner;

import org.json.JSONException;
import org.json.JSONObject;

import android.content.res.AssetManager;
import android.util.Base64;
import android.util.Log;

public class CouchMover
{
	public interface LoaderCallback { public InputStream loadAsInputStream(); }
    final class AssetManagerDocumentLoaderCallback implements LoaderCallback
    {
    	private AssetManager assetManager; private String documentPath;
    	public AssetManagerDocumentLoaderCallback(AssetManager inAssetManager, String inDocumentPath) { assetManager = inAssetManager; documentPath = inDocumentPath; }
		public InputStream loadAsInputStream() { return CouchMover.readAssetAsInputStream(assetManager, documentPath);}
	};

	private String serverURLString;
	private String databaseName;

	protected String _credentialString;
	
	protected static final String LOG_TAG = "CouchMover";
	private class HTTPURLResponse 
	{
		public String responseString; public JSONObject json; public int statusCode; public Map<String, List<String>> headers;
		public HTTPURLResponse(String responseString, JSONObject json, int statusCode, Map<String, List<String>> headers) { this.responseString = responseString; this.json = json; this.statusCode = statusCode; this.headers = headers;}
	};

	protected static final String ACCEPT_TYPE_JSON              		= "application/json";
	protected static final String CONTENT_TYPE_JSON              		= "application/json; charset=UTF-8";
	protected static final String CONTENT_TYPE_FORM              		= "multipart/form-data";
	protected static final String COUCHAPP_LOADED_VERSION_DOC    		= "loaded_version";
	protected static final String COUCHAPP_LOADED_VERSION_FIELD  		= "loaded_rev";
	private boolean RESPONSE_DATA_OK(HTTPURLResponse data)				{return responseDataHasFieldAndValue(data, "ok", "true");}
	private boolean RESPONSE_DATA_DB_EXISTS(HTTPURLResponse data)		{return responseDataHasField(data, "db_name");}
	private boolean RESPONSE_DATA_DOC_EXISTS(HTTPURLResponse data)		{return responseDataHasField(data, "_id");}

	public CouchMover(String inServerURLString, PasswordAuthentication inServerCredential, String inDatabaseName) 
	{
		serverURLString = (inServerURLString!=null) ? new String(inServerURLString) : null;
		databaseName = (inDatabaseName!=null) ? new String(inDatabaseName) : null;
		_credentialString = null;
		setServerCredential(inServerCredential);
    }
	
	public void setDatabaseName(String inDatabaseName)
	{
		databaseName = new String(inDatabaseName);
	}
	
	public void setServerCredential(PasswordAuthentication inServerCredential)
	{
	    if(inServerCredential != null)
	    {
	    	String tempString = String.format("%s:%s", inServerCredential.getUserName(), inServerCredential.getPassword());
	        _credentialString = "Basic "+ Base64.encodeToString(tempString.getBytes(),Base64.URL_SAFE|Base64.NO_WRAP);
	    }
	    else
	    {
	        _credentialString = null;
	    }
	}

    public boolean ensureDatabaseExists() 
	{
	    String databaseURL = urlToDatabase();
	    HTTPURLResponse responseData;
		
	    /////////////////////////
	    // check existence - GET
	    /////////////////////////
	    responseData = serverHTTPURLResponse(databaseURL, "GET");
	    
	    // failed to connect to server or parse response
	    if(responseData==null) 
	    {
			Log.v(LOG_TAG, String.format("Failed to connect to the server at: %s", databaseURL));
	        return false;
	    }
	    
	    // the DB exists
	    if(RESPONSE_DATA_DB_EXISTS(responseData))
	        return true;
	    
	    /////////////////////////
	    // doesn't exist so create - PUT
	    /////////////////////////
	    responseData = serverHTTPURLResponse(databaseURL, "PUT");
	    return RESPONSE_DATA_OK(responseData);
	}

	public boolean documentHasChanged(String documentName, String version)
	{
	    // call this first because loadDocument calls this
	    ensureDatabaseExists();

	    // no version so always load
	    if(version==null)
	        return true;
	    
	    // no change so do not upload
	    String currentVersion = getCurrentDocumentVersion(documentName);
	    return((currentVersion == null) || (currentVersion.compareTo(version) != 0));
	}

	public boolean loadDocument(String documentName, String version, LoaderCallback documentLoaderCallback)
	{
	    // no change in the document
	    if(!documentHasChanged(documentName,version))
	        return true;
	    
	    String documentURL = urlToDocument(documentName);
	    HTTPURLResponse responseData;
	    
	    /////////////////////////
	    // check existence of document - HEAD and if it does, DELETE it before update
	    // NOTE: this is to avoid having to update the provided document with the _rev parameter from the existing document
	    /////////////////////////

	    // get the current revision if document exists
	    responseData = serverHTTPURLResponse(documentURL, "HEAD", null, null, true);
	    List<String> Values = ((responseData!=null) && (responseData.headers!=null)) ? responseData.headers.get("Etag") : null; 
	    String _revCurrent = (Values!=null) && (!Values.isEmpty()) ? Values.get(0): null;
	    	
	    // delete the current document
	    if(_revCurrent != null)
	        serverHTTPURLResponse_DeleteDocument(documentURL, _revCurrent);
	    
	    // create
	    responseData = serverHTTPURLResponse(documentURL, "PUT", documentLoaderCallback.loadAsInputStream(), CONTENT_TYPE_FORM, false);

	    boolean success = RESPONSE_DATA_OK(responseData);
	    if(!success)
	        Log.v(LOG_TAG, String.format("Failed to create the document at URL: %s", documentURL));

	    // update the version -> if there is no revision, skip and it will be loaded again next time
	    else
	        setCurrentDocumentVersion(documentName, version);
	    
	    return success;
	}

	public boolean loadDocumentFromAssetManager(AssetManager assetManager, String documentName, String documentAssetPath, String versionAssetPath)
	{
	    String version = inputStreamToString(CouchMover.readAssetAsInputStream(assetManager, versionAssetPath));
	    
	    if(version==null)
	    {
	        Log.v(LOG_TAG, String.format("Failed to find the bundle resource: %s", versionAssetPath));
	        return false;
	    }
		
	    // load the document if needed
	    return loadDocument(documentName, version, new AssetManagerDocumentLoaderCallback(assetManager, documentAssetPath));
	}

	public static InputStream readAssetAsInputStream(AssetManager assetManager, String assetPath)
	{
		try 
		{
			return assetManager.open(assetPath);
		} 
		catch (IOException e) 
		{
			e.printStackTrace();
		}
		
		return null;
	}
	
	public static String inputStreamToString(InputStream inputStream)
	{
		if(inputStream==null)
			return null;
		
		return new Scanner(inputStream, "UTF-8").useDelimiter("\\A").next();
	}

	public static void copyInputToOutputStream(InputStream inputStream, OutputStream outputStream)
	{
		final int MAX_COPY_BUFFER_SIZE = 64 * 1024; 
		
		try 
		{
			int bufferSize = inputStream.available();
			if(bufferSize>MAX_COPY_BUFFER_SIZE)
				bufferSize = MAX_COPY_BUFFER_SIZE;
			byte[] buffer = new byte[bufferSize];
			int length;

			while(true) 
			{
				length = inputStream.read(buffer);
				if (length < 0)
					break;
				outputStream.write(buffer, 0, length);
			}
		
			// close it, this is implicit knowledge that the input buffers are owned by the caller of this function and hopefully there are no memory leaks for failure conditions
			inputStream.close();
		} 
		catch (IOException e) 
		{
		}
	}
	
    public void gotoAppPage(String appDocumentName, android.webkit.WebView webView, String page)
	{
	    String couchappAppPageURL = String.format("%s/%s", urlToDocument(appDocumentName), page);
	    webView.loadUrl(couchappAppPageURL);
	}

	///////////////////////
	// Internal Flow
	///////////////////////
	private String getCurrentDocumentVersion(String documentName)
	{
	    String documentURL = urlToLoadedDocumentVerionDocument(documentName);
	    HTTPURLResponse responseData;
	    
	    /////////////////////////
	    // check existence - GET
	    /////////////////////////
	    responseData = serverHTTPURLResponse(documentURL, "GET");
	    
	    // failed to connect to server or parse response
	    if(responseData==null) 
	        return null;

	    // get the key field key
	    return RESPONSE_DATA_DOC_EXISTS(responseData)? responseDataExtractStringValue(responseData, COUCHAPP_LOADED_VERSION_FIELD) : null;
	}

	private void setCurrentDocumentVersion(String documentName, String version)
	{
	    String documentURL = urlToLoadedDocumentVerionDocument(documentName);
	    HTTPURLResponse responseData;
	    
	    /////////////////////////
	    // check existence - GET
	    /////////////////////////
	    responseData = serverHTTPURLResponse(documentURL, "GET");
	    
	    // exists, delete
	    if(RESPONSE_DATA_DOC_EXISTS(responseData))
	    {
	        String _revCurrent = responseDataExtractStringValue(responseData, "_rev");
	        serverHTTPURLResponse_DeleteDocument(documentURL, _revCurrent);
	    }
	    
	    String versionDocument = String.format("{\"%s\":\"%s\"}", COUCHAPP_LOADED_VERSION_FIELD, version);
	    
	    // create
	    responseData = serverHTTPURLResponse(documentURL, "PUT", new ByteArrayInputStream(versionDocument.getBytes(), 0, versionDocument.length()), CONTENT_TYPE_FORM, false);
	    if(!RESPONSE_DATA_OK(responseData))
	        Log.v(LOG_TAG, String.format("Failed to create the document version document at URL: %s", documentURL));
	}

	///////////////////////
	// URL Helpers
	///////////////////////
	private String urlToDatabase()
	{
	    return String.format("%s%s", serverURLString, databaseName);
	}

	private String urlToDocument(String documentName)
	{
	    return String.format("%s%s/%s", serverURLString, databaseName, documentName);
	}

	private String urlToLoadedDocumentVerionDocument(String documentName)
	{
	    if(documentName.startsWith("_design"))
	        return String.format("%s%s/%s_%s", serverURLString, databaseName, documentName, COUCHAPP_LOADED_VERSION_DOC);

	    // make sure _design starts with _design so it is skipped in view generation
	    else
	        return String.format("%s%s/_design/%s_%s", serverURLString, databaseName, documentName, COUCHAPP_LOADED_VERSION_DOC);
	}

	///////////////////////
	// HTTP Helpers
	///////////////////////
	private HTTPURLResponse serverHTTPURLResponse(String urlString, String httpMethod)
	{
		return serverHTTPURLResponse(urlString, httpMethod, null, null, false);
	}

	private HTTPURLResponse serverHTTPURLResponse(String urlString, String httpMethod, InputStream dataStream, String contentType, boolean includeHeaders)
	{
		String responseString = null;
		int statusCode = 0;
		Map<String, List<String>> headers = null;

		try {

			HttpURLConnection connection = (HttpURLConnection) new URL(urlString).openConnection();

			connection.setDoOutput(true);
			connection.setUseCaches(false);

			connection.setRequestMethod(httpMethod);
			connection.setRequestProperty("Accept", ACCEPT_TYPE_JSON);
			
			if(_credentialString!=null)
				connection.setRequestProperty(_credentialString, "Authorization");

			if((dataStream!=null)&&(contentType!=null))
			{
				connection.setDoInput(true);
				connection.setRequestProperty("Referer", urlString);
				connection.setRequestProperty("Content-type", contentType);
				connection.setRequestProperty("Content-Length", Integer.toString(dataStream.available()));
				copyInputToOutputStream(dataStream, connection.getOutputStream());
			}
			else
				connection.setRequestProperty("Content-type", CONTENT_TYPE_JSON);

			// call and get response
			connection.connect();
			statusCode = connection.getResponseCode();

			try 
			{
				// HEAD response is header only
				if(httpMethod!="HEAD")
				{
				    BufferedReader rd = new BufferedReader(new InputStreamReader(connection.getInputStream()));
					StringBuilder sb = new StringBuilder();
				    String line = null;
			        
			        while ((line = rd.readLine()) != null)
			        {
			        	sb.append(line);
			        }
					rd.close();
					responseString = sb.toString();
	
					//Log.v(LOG_TAG, String.format("Response string: %s", responseString));
				}				
			} catch (FileNotFoundException e) {

			} catch (NullPointerException e) {

			}

			finally {
				if((httpMethod=="HEAD") || (includeHeaders))
					headers = connection.getHeaderFields();
				
				connection.disconnect();
			}

		} catch (IOException e) {
			e.printStackTrace();
		}

		try
		{
			JSONObject json = ((responseString==null) || (responseString.length() == 0))
				? new JSONObject()
				: new JSONObject(responseString);

			return new HTTPURLResponse(responseString, json, statusCode, headers);
		} 
		catch (JSONException e) 
		{
			e.printStackTrace();
		}
		
		return null;
	}
	
	private boolean serverHTTPURLResponse_DeleteDocument(String urlString, String _revCurrent)
	{
	    // generate the URL including the rev parameter (removing the quotes)
	    String documentURLDelete = String.format("%s?rev=%s", urlString, _revCurrent.replaceAll("\"", ""));
	    HTTPURLResponse responseData = serverHTTPURLResponse(documentURLDelete, "DELETE");
	    if(!RESPONSE_DATA_OK(responseData))
	    {
	        Log.v(LOG_TAG, String.format("Failed to delete the at URL: %s", documentURLDelete));
	        return false;
	    }
	    
	    return true;
	}

	boolean responseDataHasFieldAndValue(HTTPURLResponse data, String field, String value)
	{
		try 
		{
			return (data.json.getString(field).compareTo(value)==0);
		} 
		catch (JSONException e) 
		{
			// OK, it may not exist
		}
		
		return false;
	}

	boolean responseDataHasField(HTTPURLResponse data, String field)
	{
		try 
		{
			return (data.json.get(field)!=null);
		} 
		catch (JSONException e) 
		{
			// OK, it may not exist
		}
		
		return false;
	}

	String responseDataExtractStringValue(HTTPURLResponse data, String field)
	{
		try 
		{
			return data.json.getString(field);
		} 
		catch (JSONException e) 
		{
			// OK, it may not exist
		}
		
		return null;
	}
}
    
