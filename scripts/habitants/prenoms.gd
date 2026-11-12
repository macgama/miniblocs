class_name Prenoms
extends RefCounted
## Prénoms et noms de famille des habitants, par région du monde.
##
## La région d'un foyer vient du style de son logement (une maison japonaise
## accueille plutôt une famille aux noms japonais), sinon du lieu de départ
## choisi sur le globe. Un peu de mélange rend les villes plus vivantes.

const POOLS := {
	"europe": {
		"F": ["Emma", "Louise", "Jade", "Alice", "Chloé", "Léa", "Manon", "Camille", "Zoé", "Inès", "Lina", "Rose", "Anna", "Julie", "Sarah", "Claire", "Sophie", "Marie", "Nathalie", "Isabelle", "Monique", "Françoise", "Jeanne", "Lucie", "Élise", "Margaux", "Clara", "Agathe", "Mathilde", "Juliette"],
		"H": ["Gabriel", "Léo", "Raphaël", "Louis", "Arthur", "Jules", "Hugo", "Lucas", "Adam", "Nathan", "Paul", "Tom", "Théo", "Noah", "Maël", "Thomas", "Nicolas", "Julien", "Pierre", "Philippe", "Michel", "Bernard", "Jean", "Antoine", "Baptiste", "Mathis", "Victor", "Gaël", "Yann", "Benoît"],
		"N": ["Martin", "Bernard", "Thomas", "Petit", "Robert", "Richard", "Durand", "Dubois", "Moreau", "Laurent", "Simon", "Michel", "Lefebvre", "Leroy", "Roux", "David", "Bertrand", "Morel", "Fournier", "Girard", "Bonnet", "Dupont", "Lambert", "Fontaine", "Rousseau", "Vincent", "Muller", "Lefèvre", "Faure", "André", "Mercier", "Blanc", "Guérin", "Boyer", "Garnier", "Chevalier", "Le Gall", "Morvan", "Schmitt", "Weber"],
	},
	"mediterranee": {
		"F": ["Giulia", "Sofia", "Aurora", "Lucía", "Martina", "Elena", "Maria", "Chiara", "Carmen", "Paula", "Eleni", "Ana", "Inês", "Beatriz", "Francesca"],
		"H": ["Leonardo", "Francesco", "Alessandro", "Lorenzo", "Hugo", "Mateo", "Pablo", "Diego", "Giorgos", "Nikos", "João", "Tiago", "Marco", "Antonio", "Javier"],
		"N": ["Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "García", "Rodríguez", "Fernández", "López", "Martínez", "Papadopoulos", "Silva", "Santos", "Costa", "Romano", "Navarro", "Pereira", "Moreno"],
	},
	"moyen_orient": {
		"F": ["Fatima", "Amina", "Leila", "Yasmine", "Nour", "Salma", "Meriem", "Rania", "Zeynep", "Aya", "Samira", "Lina", "Imane", "Hiba", "Elif"],
		"H": ["Mohamed", "Ahmed", "Youssef", "Omar", "Karim", "Ali", "Hassan", "Mehdi", "Rayan", "Emre", "Amine", "Bilal", "Samir", "Tarek", "Yassine"],
		"N": ["Benali", "El Amrani", "Haddad", "Mansour", "Khalil", "Saïdi", "Bouzid", "Yılmaz", "Kaya", "Demir", "Nasser", "Rahmani", "Cherif", "Aziz", "Hamdi", "Toumi"],
	},
	"afrique": {
		"F": ["Aminata", "Fatoumata", "Awa", "Mariam", "Aïssatou", "Chiamaka", "Ngozi", "Amara", "Zawadi", "Nia", "Adjoa", "Kadiatou", "Esi", "Thandiwe", "Imani"],
		"H": ["Mamadou", "Moussa", "Ibrahima", "Kwame", "Kofi", "Chinedu", "Oluwaseun", "Sékou", "Abdoulaye", "Jabari", "Thabo", "Babacar", "Yao", "Kouassi", "Ousmane"],
		"N": ["Diallo", "Traoré", "Koné", "Diop", "Ndiaye", "Camara", "Mensah", "Okafor", "Adeyemi", "Mbeki", "Kamau", "Ouédraogo", "Sow", "Bamba", "Nkosi", "Asante", "Owusu", "Coulibaly"],
	},
	"asie_est": {
		"F": ["Yui", "Sakura", "Hina", "Aoi", "Mei", "Xiu", "Li Na", "Ji-woo", "Seo-yeon", "Haruka", "Yuna", "Lan", "Mio", "Min-ji", "Wen"],
		"H": ["Haruto", "Ren", "Sota", "Yuto", "Wei", "Jun", "Hao", "Min-jun", "Seo-jun", "Kenji", "Takumi", "Hiroshi", "Jian", "Ji-ho", "Daiki"],
		"N": ["Satō", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Itō", "Yamamoto", "Wang", "Li", "Zhang", "Liu", "Chen", "Kim", "Lee", "Park", "Choi", "Nakamura", "Kobayashi"],
	},
	"asie_sud": {
		"F": ["Aanya", "Diya", "Priya", "Ananya", "Saanvi", "Lakshmi", "Nguyen Thi Lan", "Siti", "Putri", "Mai", "Anjali", "Kavya", "Dewi", "Linh", "Ayesha"],
		"H": ["Aarav", "Vivaan", "Arjun", "Rohan", "Rahul", "Sanjay", "Minh", "Duc", "Budi", "Agus", "Ravi", "Imran", "Rizal", "Somchai", "Vikram"],
		"N": ["Sharma", "Patel", "Singh", "Kumar", "Gupta", "Nguyen", "Tran", "Le", "Pham", "Santoso", "Wijaya", "Rahman", "Khan", "Das", "Reddy", "Iyer", "Saetang"],
	},
	"ameriques": {
		"F": ["Olivia", "Emma", "Ava", "Sophia", "Isabella", "Mia", "Valentina", "Camila", "Ximena", "Gabriela", "Emily", "Madison", "Luana", "Ana Clara", "Abigail"],
		"H": ["Liam", "Noah", "Oliver", "Elijah", "James", "Santiago", "Matías", "Sebastián", "Miguel", "Gabriel", "Ethan", "Mason", "Lucas", "Benjamín", "Davi"],
		"N": ["Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Wilson", "González", "Hernández", "Pérez", "Sánchez", "Ramírez", "Oliveira", "Souza", "Tremblay", "Gagnon", "Taylor"],
	},
	"oceanie": {
		"F": ["Charlotte", "Amelia", "Isla", "Matilda", "Ruby", "Aroha", "Mere", "Ana", "Grace", "Harper", "Kaia", "Leilani", "Ivy", "Mila", "Willow"],
		"H": ["Oliver", "Jack", "William", "Leo", "Henry", "Nikau", "Tane", "Manaia", "Lachlan", "Cooper", "Hunter", "Kai", "Mason", "Archie", "Hamish"],
		"N": ["Smith", "Jones", "Williams", "Brown", "Wilson", "Taylor", "Ngata", "Parata", "Tamihana", "Fifita", "Tupou", "Kelly", "Ryan", "Campbell", "Murphy", "Walker"],
	},
}


## Région des noms d'après un lieu (latitude, longitude), grossièrement par continent.
static func region_for_place(lat: float, lon: float) -> String:
	if lon < -30.0:
		return "ameriques"
	if lat < -10.0 and lon > 110.0:
		return "oceanie"
	if lon > 95.0 and lat > 18.0:
		return "asie_est"
	if lon > 60.0:
		return "asie_sud"
	if lat < 15.0 and lon > -20.0:
		return "afrique"
	if lat < 36.0 and lon > 25.0:
		return "moyen_orient"
	if lat < 34.0:
		return "moyen_orient" if lon > -10.0 else "afrique"
	if lat < 44.0 and lon < 28.0:
		return "mediterranee"
	return "europe"


static func pool(region: String) -> Dictionary:
	return POOLS.get(region, POOLS.europe)


static func first_name(rng: RandomNumberGenerator, region: String, sex: String) -> String:
	var list: Array = pool(region)[sex]
	return String(list[rng.randi() % list.size()])


static func family_name(rng: RandomNumberGenerator, region: String) -> String:
	var list: Array = pool(region).N
	return String(list[rng.randi() % list.size()])
