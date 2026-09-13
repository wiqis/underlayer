// underlayer_web — Learner CRUD handlers.
using std::string
using std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    public func handle_create_learner(db : *DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        var learner_id = underlayer_core::int_to_string(underlayer_core::current_timestamp())
        var name = std::string("learner")
        var email = std::string("learner@underlayer.dev")
        underlayer_repository::create_learner(db, &learner_id, &name, &email)
        var body = std::string("{\"id\":\"")
        body.append_view(learner_id.to_view())
        body.append_view("\",\"name\":\"")
        body.append_view(name.to_view())
        body.append_view("\",\"email\":\"")
        body.append_view(email.to_view())
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

    public func handle_get_learner(db : *DbClient, learner_id : *string_view, req : &http::Request, res : *mut http::ResponseWriter) {
        var lid = sv_to_string(learner_id)
        var learner = underlayer_repository::get_learner(db, &lid)
        if(learner.id.size() == 0) {
            var err = std::string("learner not found")
            send_error(res, 404u, &err)
            return
        }
        var body = std::string("{\"id\":\"")
        body.append_string(&learner.id)
        body.append_view("\",\"name\":\"")
        body.append_string(&learner.name)
        body.append_view("\",\"email\":\"")
        body.append_string(&learner.email)
        body.append_view("\"}")
        send_json_str(res, &raw body)
    }

}
