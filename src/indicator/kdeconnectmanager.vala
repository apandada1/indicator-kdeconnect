/* Copyright 2018 KDE Connect Indicator Developers
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

using Gee;

namespace IndicatorKDEConnect {
    public class KDEConnectManager : Object, IDaemon {
        private DBusConnection conn;        
        private HashSet<Device> devices_connected;
        private HashSet<uint> subs_identifier;                    

        public KDEConnectManager () {
            try {
                conn = Bus.get_sync (BusType.SESSION);

                if (assert_kdeconnect_service ()) {                    
                    devices_connected = new HashSet<Device> ();
                    subs_identifier = new HashSet<uint>();

                    fill_devices ();               

                    uint id;                    

                    id = subscribe_device_added (ref conn);
                
                    subs_identifier.add (id);

                    id = subscribe_device_removed (ref conn);

                    subs_identifier.add (id);

                    id = subscribe_device_visibility_changed (ref conn);
                
                    subs_identifier.add (id);

                    id = subscribe_device_removed (ref conn);

                    subs_identifier.add (id);
            
                                                     
                }
                else {
                    new ErrorMessage.show_message("Cannot connect to KDEConnect DBus Service");
                    return;
                }
            } 
            catch (Error e) {
                debug (e.message);
            }
        }

        ~KDEConnectManager () {
            subs_identifier.@foreach ( (item) => { 
                conn.signal_unsubscribe (item);
            });

            conn.call_sync ("org.kde.kdeconnect",
                            "/modules/kdeconnect",
                            "org.kde.kdeconnect.daemon",
                            "releaseDiscoveryMode",
                            new Variant ("(s)", "Indicator-KDEConnect"),
                            null,
                            DBusCallFlags.NONE,
                            -1,
                            null); 
        }

        private bool assert_kdeconnect_service () {            
            var return_value = false;            
            var max_trying = 4;

            while (!return_value) {                        
                return_value = is_daemon_running ();

                if (!return_value) {
                    Utils.run_kdeconnect_deamon ();
                    Thread.usleep (500);
                    message ("Trying to find KDEConnect DBus Service");
                }
                max_trying--;

                if (max_trying <= 0)
                    break;                                                                                 
            }

            return return_value;
        }

        private bool is_daemon_running () {
            var return_value = false;

            try {
                var device_proxy = daemon_proxy (ref conn);

                return_value = (device_proxy.get_name_owner () != null);
            } 
            catch (Error e) {
                debug (e.message);
            }

            return return_value;
        }

        private void fill_devices () {
            string[] devs = devices (ref conn);

            foreach (var dev in devs) {
                var path = "/modules/kdeconnect/devices/"+dev;            
                devices_connected.add (new Device (path));
                message ("Device Indicator created: %s", path);
            }

            if (devices_connected.size == 0)
                message ("No trusted device found, open KDE Connect in your phone to start pairing");
        }          
        
        public void add_device (string path) {
            message ("Device added To list of devices, %s", path);            
            devices_connected.add (new Device (path));
        }
        
        public void remove_device (string path) {
            message ("Device removed from list of devices, %s", path);
            foreach (var dev in devices_connected) {
                if (dev.path == path) {
                    devices_connected.remove (dev);
                    break;
                }
            }
        }

        public void distribute_visibility_changes (string path,
                                                   bool visible) {
            message ("Device %s visibility change to %s", path, visible.to_string ());

        }    
    }
}