// underlayer_learning — Knowledge health computation.
using std::string
using std::vector
using underlayer_models::ConceptState

public namespace underlayer_learning {

    public struct KnowledgeHealth {
        var total_concepts : int
        var mastered : int
        var learning : int
        var reviewing : int
        var unlearned : int
        var health_score : f64

        @make
        func make() : KnowledgeHealth {
            return KnowledgeHealth {
                total_concepts = 0,
                mastered = 0,
                learning = 0,
                reviewing = 0,
                unlearned = 0,
                health_score = 0.0
            }
        }
    }

    public func compute_knowledge_health(states : *vector<ConceptState>) : KnowledgeHealth {
        var health = KnowledgeHealth::make()
        health.total_concepts = states.size() as int

        var i : size_t = 0
        while(i < states.size()) {
            var state = states.get_ptr(i)
            if(state.status.equals(string("mastered"))) {
                health.mastered = health.mastered + 1
            } else if(state.status.equals(string("learning"))) {
                health.learning = health.learning + 1
            } else if(state.status.equals(string("reviewing"))) {
                health.reviewing = health.reviewing + 1
            } else {
                health.unlearned = health.unlearned + 1
            }
            i = i + 1
        }

        if(health.total_concepts > 0) {
            health.health_score = (health.mastered as f64) / (health.total_concepts as f64)
        }

        return health
    }

}
