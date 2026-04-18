var helper = require('./../helpers/helpers')
const admin = require('./../index') // جاري استيراد نسخة الـ admin التي قمنا بإعدادها
const db = admin.firestore()

module.exports.controller = (app, io, socket_list) => {

    const msg_success = "successfully"
    const msg_fail = "fail"

    const car_location_obj = {

    }

    app.post('/api/car_join', (req, res) => {
        helper.Dlog(req.body);
        var reqObj = req.body;

        helper.CheckParameterValid(res, reqObj, ['uuid', 'lat', 'long', 'degree', 'socket_id'], () => {

            socket_list['us_' + reqObj.uuid] = { 'socket_id': reqObj.socket_id }

            car_location_obj[reqObj.uuid] = {
                'uuid': reqObj.uuid, 'lat': reqObj.lat, 'long': reqObj.long, 'degree': reqObj.degree
            }

            io.emit("car_join", {
                "status": "1",
                "payload": {
                    'uuid': reqObj.uuid, 'lat': reqObj.lat, 'long': reqObj.long, 'degree': reqObj.degree
                }
            })

            // ✅ حفظ في Firebase Firestore
            db.collection('active_cars').doc(reqObj.uuid).set({
                'uuid': reqObj.uuid,
                'lat': parseFloat(reqObj.lat),
                'long': parseFloat(reqObj.long),
                'degree': parseFloat(reqObj.degree),
                'last_update': admin.firestore.FieldValue.serverTimestamp(),
                'status': 'online'
            }, { merge: true }).catch(err => helper.Dlog("Firestore Error: " + err));

            res.json({ "status": "1", "payload": car_location_obj, "message": msg_success })

        })

    })

    app.post('/api/car_update_location', (req, res) => {
        helper.Dlog(req.body);
        var reqObj = req.body;

        helper.CheckParameterValid(res, reqObj, ['uuid', 'lat', 'long', 'degree', 'socket_id'], () => {

            socket_list['us_' + reqObj.uuid] = { 'socket_id': reqObj.socket_id }

            car_location_obj[reqObj.uuid] = {
                'uuid': reqObj.uuid, 'lat': reqObj.lat, 'long': reqObj.long, 'degree': reqObj.degree
            }

            io.emit("car_update_location", {
                "status": "1",
                "payload": {
                    'uuid': reqObj.uuid, 'lat': reqObj.lat, 'long': reqObj.long, 'degree': reqObj.degree
                }
            })

            // ✅ تحديث في Firebase Firestore
            db.collection('active_cars').doc(reqObj.uuid).set({
                'lat': parseFloat(reqObj.lat),
                'long': parseFloat(reqObj.long),
                'degree': parseFloat(reqObj.degree),
                'last_update': admin.firestore.FieldValue.serverTimestamp(),
                'status': 'online'
            }, { merge: true }).catch(err => helper.Dlog("Firestore Update Error: " + err));

            res.json({ "status": "1", "message": msg_success })

        })

    })

}
