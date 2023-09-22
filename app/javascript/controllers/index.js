// Eager load all controllers defined in the import map under controllers/**/*_controller
import { application } from "controllers/application"

import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
