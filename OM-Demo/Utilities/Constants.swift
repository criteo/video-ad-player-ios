//
//  Constants.swift
//  OM-TestApp
//
//  Created by Nathanael Hardy on 4/12/18.
//

import Foundation

struct Constants {
    
    /// Vast URL example with Video + Closed Captions
    static var vastURL = "https://raw.githubusercontent.com/criteo/interview-ios/refs/heads/main/server/sample_vast_app.xml"
    
    // Examples below should be used with "source: .xml"
    // i.e `let videoAd = CriteoVideoAdWrapper(source: .xml(<VAST...</VAST>), configuration: config)`
    
    /// Same as the above but in String form. Video + CC
    static var vastXML = """
<?xml version="1.0" encoding="utf-8"?>
<VAST xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema" version="4.2">
    <Ad id="609475258823917568">
        <InLine>
            <AdSystem>Criteo</AdSystem>
            <AdTitle>OnsiteVideo</AdTitle>
            <Impression><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/impression]]></Impression>
            <Error><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/error]]></Error>
            <Creatives>
                <Creative id="35934">
                    <Linear>
                        <Duration>00:00:17</Duration>
                        <TrackingEvents>
                            <Tracking event="start"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/start]]></Tracking>
                            <Tracking event="firstQuartile"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/firstQuartile]]></Tracking>
                            <Tracking event="midpoint"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/midpoint]]></Tracking>
                            <Tracking event="thirdQuartile"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/thirdQuartile]]></Tracking>
                            <Tracking event="complete"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/complete]]></Tracking>
                            <Tracking event="mute"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/mute]]></Tracking>
                            <Tracking event="unmute"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/unmute]]></Tracking>
                            <Tracking event="pause"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/pause]]></Tracking>
                            <Tracking event="resume"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/resume]]></Tracking>
                        </TrackingEvents>
                        <MediaFiles>
                            <MediaFile id="id" delivery="progressive" width="640" height="360" type="video/mp4" scalable="true" maintainAspectRatio="true"><![CDATA[https://raw.githubusercontent.com/criteo/interview-ios/refs/heads/main/server/criteo.mp4]]></MediaFile>
                            <ClosedCaptionFiles>
                                <ClosedCaptionFile type="text/vtt" language="en"><![CDATA[https://raw.githubusercontent.com/criteo/interview-ios/refs/heads/main/server/criteo.vtt]]></ClosedCaptionFile>
                            </ClosedCaptionFiles>
                        </MediaFiles>
                        <VideoClicks>
                            <ClickTracking><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/click]]></ClickTracking>
                        </VideoClicks>
                    </Linear>
                </Creative>
            </Creatives>
            <AdVerifications>
                <Verification vendor="criteo.com-omid">
                    <JavaScriptResource apiFramework="omid" browserOptional="true"><![CDATA[https://static.criteo.net/banners/js/omidjs/stable/omid-validation-verification-script-for-retail-media.js]]></JavaScriptResource>
                    <VerificationParameters><![CDATA[{"beacons":{
                        "omidTrackView":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/omidTrackView",
                        "start":                      "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/start",
                        "firstQuartile":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/firstQuartile",
                        "midpoint":                   "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/midpoint",
                        "thirdQuartile":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/thirdQuartile",
                        "complete":                   "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/complete",
                        "twoSecondsFiftyPercentView": "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/twoSecondsFiftyPercentView"
                    }}]]>
                </VerificationParameters>
                    <TrackingEvents>
                        <Tracking event="verificationNotExecuted"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/verificationNotExecuted]]></Tracking>
                    </TrackingEvents>
                </Verification>
            </AdVerifications>
        </InLine>
    </Ad>
</VAST>
"""
    
    /// Video + CC + ClickThrough url
    static var vastXMLWithURL = """
<?xml version="1.0" encoding="utf-8"?>
<VAST xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema" version="4.2">
    <Ad id="609475258823917568">
        <InLine>
            <AdSystem>Criteo</AdSystem>
            <AdTitle>OnsiteVideo</AdTitle>
            <Impression><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/impression]]></Impression>
            <Error><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/error]]></Error>
            <Creatives>
                <Creative id="35934">
                    <Linear>
                        <Duration>00:00:17</Duration>
                        <TrackingEvents>
                            <Tracking event="start"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/start]]></Tracking>
                            <Tracking event="firstQuartile"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/firstQuartile]]></Tracking>
                            <Tracking event="midpoint"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/midpoint]]></Tracking>
                            <Tracking event="thirdQuartile"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/thirdQuartile]]></Tracking>
                            <Tracking event="complete"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/complete]]></Tracking>
                            <Tracking event="mute"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/mute]]></Tracking>
                            <Tracking event="unmute"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/unmute]]></Tracking>
                            <Tracking event="pause"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/pause]]></Tracking>
                            <Tracking event="resume"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/resume]]></Tracking>
                        </TrackingEvents>
                        <MediaFiles>
                            <MediaFile id="id" delivery="progressive" width="640" height="360" type="video/mp4" scalable="true" maintainAspectRatio="true"><![CDATA[https://raw.githubusercontent.com/criteo/interview-ios/refs/heads/main/server/criteo.mp4]]></MediaFile>
                            <ClosedCaptionFiles>
                                <ClosedCaptionFile type="text/vtt" language="en"><![CDATA[https://raw.githubusercontent.com/criteo/interview-ios/refs/heads/main/server/criteo.vtt]]></ClosedCaptionFile>
                            </ClosedCaptionFiles>
                        </MediaFiles>
                        <VideoClicks>
                            <ClickThrough><![CDATA[https://www.criteo.com/]]></ClickThrough>
                            <ClickTracking><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/click]]></ClickTracking>
                        </VideoClicks>
                    </Linear>
                </Creative>
            </Creatives>
            <AdVerifications>
                <Verification vendor="criteo.com-omid">
                    <JavaScriptResource apiFramework="omid" browserOptional="true"><![CDATA[https://static.criteo.net/banners/js/omidjs/stable/omid-validation-verification-script-for-retail-media.js]]></JavaScriptResource>
                    <VerificationParameters><![CDATA[{"beacons":{
                        "omidTrackView":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/omidTrackView",
                        "start":                      "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/start",
                        "firstQuartile":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/firstQuartile",
                        "midpoint":                   "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/midpoint",
                        "thirdQuartile":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/thirdQuartile",
                        "complete":                   "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/complete",
                        "twoSecondsFiftyPercentView": "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/twoSecondsFiftyPercentView"
                    }}]]>
                </VerificationParameters>
                    <TrackingEvents>
                        <Tracking event="verificationNotExecuted"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/verificationNotExecuted]]></Tracking>
                    </TrackingEvents>
                </Verification>
            </AdVerifications>
        </InLine>
    </Ad>
</VAST>
"""
    /// Video only
    static var vastXMLJustVideo = """
<?xml version="1.0" encoding="utf-8"?>
<VAST xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema" version="4.2">
    <Ad id="609475258823917568">
        <InLine>
            <AdSystem>Criteo</AdSystem>
            <AdTitle>OnsiteVideo</AdTitle>
            <Impression><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/impression]]></Impression>
            <Error><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/error]]></Error>
            <Creatives>
                <Creative id="35934">
                    <Linear>
                        <Duration>00:00:17</Duration>
                        <TrackingEvents>
                            <Tracking event="start"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/start]]></Tracking>
                            <Tracking event="firstQuartile"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/firstQuartile]]></Tracking>
                            <Tracking event="midpoint"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/midpoint]]></Tracking>
                            <Tracking event="thirdQuartile"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/thirdQuartile]]></Tracking>
                            <Tracking event="complete"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/complete]]></Tracking>
                            <Tracking event="mute"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/mute]]></Tracking>
                            <Tracking event="unmute"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/unmute]]></Tracking>
                            <Tracking event="pause"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/pause]]></Tracking>
                            <Tracking event="resume"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/resume]]></Tracking>
                        </TrackingEvents>
                        <MediaFiles>
                            <MediaFile id="id" delivery="progressive" width="640" height="360" type="video/mp4" scalable="true" maintainAspectRatio="true"><![CDATA[https://raw.githubusercontent.com/criteo/interview-ios/refs/heads/main/server/criteo.mp4]]></MediaFile>
                        </MediaFiles>
                        <VideoClicks>
                            <ClickTracking><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/click]]></ClickTracking>
                        </VideoClicks>
                    </Linear>
                </Creative>
            </Creatives>
            <AdVerifications>
                <Verification vendor="criteo.com-omid">
                    <JavaScriptResource apiFramework="omid" browserOptional="true"><![CDATA[https://static.criteo.net/banners/js/omidjs/stable/omid-validation-verification-script-for-retail-media.js]]></JavaScriptResource>
                    <VerificationParameters><![CDATA[{"beacons":{
                        "omidTrackView":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/omidTrackView",
                        "start":                      "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/start",
                        "firstQuartile":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/firstQuartile",
                        "midpoint":                   "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/midpoint",
                        "thirdQuartile":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/thirdQuartile",
                        "complete":                   "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/complete",
                        "twoSecondsFiftyPercentView": "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/twoSecondsFiftyPercentView"
                    }}]]>
                </VerificationParameters>
                    <TrackingEvents>
                        <Tracking event="verificationNotExecuted"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/verificationNotExecuted]]></Tracking>
                    </TrackingEvents>
                </Verification>
            </AdVerifications>
        </InLine>
    </Ad>
</VAST>
"""
    
    /// Video + ClickThrough
    static var vastXMLVideoClickthrough = """
<?xml version="1.0" encoding="utf-8"?>
<VAST xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema" version="4.2">
    <Ad id="609475258823917568">
        <InLine>
            <AdSystem>Criteo</AdSystem>
            <AdTitle>OnsiteVideo</AdTitle>
            <Impression><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/impression]]></Impression>
            <Error><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/error]]></Error>
            <Creatives>
                <Creative id="35934">
                    <Linear>
                        <Duration>00:00:17</Duration>
                        <TrackingEvents>
                            <Tracking event="start"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/start]]></Tracking>
                            <Tracking event="firstQuartile"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/firstQuartile]]></Tracking>
                            <Tracking event="midpoint"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/midpoint]]></Tracking>
                            <Tracking event="thirdQuartile"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/thirdQuartile]]></Tracking>
                            <Tracking event="complete"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/complete]]></Tracking>
                            <Tracking event="mute"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/mute]]></Tracking>
                            <Tracking event="unmute"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/unmute]]></Tracking>
                            <Tracking event="pause"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/pause]]></Tracking>
                            <Tracking event="resume"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/resume]]></Tracking>
                        </TrackingEvents>
                        <MediaFiles>
                            <MediaFile id="id" delivery="progressive" width="640" height="360" type="video/mp4" scalable="true" maintainAspectRatio="true"><![CDATA[https://raw.githubusercontent.com/criteo/interview-ios/refs/heads/main/server/criteo.mp4]]></MediaFile>
                        </MediaFiles>
                        <VideoClicks>
                            <ClickThrough><![CDATA[https://www.criteo.com/]]></ClickThrough>
                            <ClickTracking><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/tracking/click]]></ClickTracking>
                        </VideoClicks>
                    </Linear>
                </Creative>
            </Creatives>
            <AdVerifications>
                <Verification vendor="criteo.com-omid">
                    <JavaScriptResource apiFramework="omid" browserOptional="true"><![CDATA[https://static.criteo.net/banners/js/omidjs/stable/omid-validation-verification-script-for-retail-media.js]]></JavaScriptResource>
                    <VerificationParameters><![CDATA[{"beacons":{
                        "omidTrackView":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/omidTrackView",
                        "start":                      "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/start",
                        "firstQuartile":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/firstQuartile",
                        "midpoint":                   "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/midpoint",
                        "thirdQuartile":              "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/thirdQuartile",
                        "complete":                   "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/complete",
                        "twoSecondsFiftyPercentView": "https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/twoSecondsFiftyPercentView"
                    }}]]>
                </VerificationParameters>
                    <TrackingEvents>
                        <Tracking event="verificationNotExecuted"><![CDATA[https://httpdump.app/dumps/59fe4255-b0c3-45ba-8b32-dbf71c8e0226/measurement/verificationNotExecuted]]></Tracking>
                    </TrackingEvents>
                </Verification>
            </AdVerifications>
        </InLine>
    </Ad>
</VAST>
"""
}

