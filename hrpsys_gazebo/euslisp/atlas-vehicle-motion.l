
;; \file    atlas-vehicle-motion.l
;; \author  Murooka Masaki
;; \date    2013/06/08
;; \brief   vrc_task_1関連関数
;;

(load "package://hrpsys_gazebo/euslisp/atlas-interface.l")
(load "package://hrpsys_gazebo/euslisp/atlas-vehicle-motion-utils.l")


;; setting
(defun make-vehicle ()
  (unless (boundp '*drcv*)
    (setq *drcv* 
	  (with-open-file 
	   (f (format nil "~a/~a" (unix:getenv "HOME") "ros/fuerte/rtm-ros-robotics/rtmros_common/hrpsys_gazebo/models/drc-vehicle.l")) (read f))))
  ;; upper-front-pipe
  (send *drcv* :add-handle
	(make-cascoords :pos #f(320 150 1920) :rpy (list 0 0 -pi/2) :name :upper-front-pipe))
  ;; (send *drcv* :add-handle
  ;; 	(make-cascoords :pos #f(320 0 1920) :rpy (list 0 0 -pi/2) :name :upper-front-pipe))
  ;; upper-left-pipe
  (send *drcv* :add-handle
	(make-cascoords :pos #f(140 575 1900) :rot (transpose (make-matrix 3 3 (list #f(0 0 -1) #f(0 -1 0) #f(-1 0 0)))) :name :upper-left-pipe))
  ;; front-left-pipe
  (send *drcv* :add-handle
	(make-cascoords :pos #f(500 600 1500) :rpy (list pi (* pi 0.125) 0) :name :front-left-pipe))
  ;; draw
  (if (boundp '*irtviewer*)
      (objects (union (send *irtviewer* :objects) (list *drcv*)))
    (objects (list *drcv*))))

(setq *vehicle-start-pos* (make-coords :pos #f(-10000 2000 0) :rpy (list -pi/2 0 0)))
(setq *vehicle-side-pos* (make-coords :pos #f(175 950 0) :rpy (list 0 0 0)))


;; move
;;;; (stand-up) on starting point [cheating!!]
(defun stand-up-start ()
  (warning-message 1 "[vhc] [cheating!!] called (stand-up-start)~%")
  (send *ri* :teleport-to (make-coords :pos (v+ (send *vehicle-start-pos* :worldpos) #f(0 0 950)) :rpy (list -pi/2 0 0))))

;;;; only teleport to starting point (not set harnessed) [cheating!!]
(defun telep-start ()
  (warning-message 1 "[vhc] [cheating!!] called (telep-start)~%")
  (ros::publish "atlas/set_pose"
		(ros::coords->tf-pose (make-coords :pos (v+ (send *vehicle-start-pos* :worldpos) #f(0 0 950)) :rpy (list -pi/2 0 0)))))

;;;; move atlas model in side of vehicle
(defun fix-leg-vehicle-side (&optional (leg :both))
  (cond
   ((equal leg :both)
    (send *atlas* :fix-leg-to-coords *vehicle-side-pos* '(:lleg :rleg)))
   (t (send *atlas* :newcoords
	    (send (send *vehicle-side-pos* :copy-worldcoords) :transform 
		  (send (send *atlas* leg :end-coords :copy-worldcoords)
			:transformation (send *atlas* :worldcoords) :local) :local)))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; vehicle motion [all]
(defun all-demo-task1
  (&key (real nil) (wait nil) (auto-walk-and-telep nil) (no-walk-and-telep nil))

  (warning-message 2 "[vhc-init] lr-reverse mode !!!~%")
  (setq *lr-reverse* t)

  (warning-message 2 "[vhc-init] start (all-demo-task1)~%")

  (init-for-task1 :real real :wait wait :auto auto-walk-and-telep)

  (unless no-walk-and-telep
    (walk-for-task1 :real real :wait wait :auto auto-walk-and-telep))

  (get-in-for-task1 :real real :wait wait :telep (or auto-walk-and-telep no-walk-and-telep))

  (warning-message 2 "[vhc-init] finish(all-demo-task1)~%")
  )


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; vehicle motion [init]
(load "package://hrpsys_gazebo/euslisp/atlas-vehicle-motion-others.l")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; vehicle motion [walk]
;; (load "package://hrpsys_gazebo/euslisp/atlas-vehicle-motion-others.l") ;; loaded above


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; vehicle motion [get-in]
(load "package://hrpsys_gazebo/euslisp/atlas-vehicle-motion-get-in.l")


(defun telep-side
  (&key (real nil) (wait nil) (init nil) (telep t))

  (when init
    (warning-message 2 "[vhc-get-in] call (my-init)~%")
    (my-init :real real)
    (send *irtviewer* :draw-objects))

  (when (and real telep)
    (warning-message 2 "[vhc-get-in] call (telep-start) and (stand-up-start)~%")
    (my-init :real real)
    (telep-start)
    (stand-up-start))

  (when real
    (warning-message 2 "[vhc-get-in] call (manip)~%")
    (when wait (my-wait))
    (manip)
    (send *irtviewer* :draw-objects))

  (warning-message 2 "[vhc-get-in] call :teleport~%")
  (when wait (my-wait))
  (when (and real telep) 
    (let* ((telep-coords (send *vehicle-side-pos* :copy-worldcoords))
	   (telep-pos (send telep-coords :worldpos))
	   (telep-rpy (car (rpy-angle (send telep-coords :rot)))))
      (setq telep-coords (make-coords :pos (float-vector (elt telep-pos 0) (- (elt telep-pos 1)) (elt telep-pos 2))
				      :rpy (list (- (elt telep-rpy 0)) (elt telep-rpy 1) (- (elt telep-rpy 2)))))
      (send telep-coords :translate #f(-70 10 0) :local)
      (send telep-coords :rotate -pi/2 :z)
      (send *ri* :teleport-to (send (send telep-coords :copy-worldcoords) :translate #f(0 0 950) :world) nil :keep-effort t)
      (send *atlas* :fix-leg-to-coords telep-coords '(:lleg :rleg))))
  (send *irtviewer* :draw-objects)

  (make-vehicle)
  )



;; usage
(defun usage ()
  (warn ";; demo~%")
  (warn "  (all-demo-task1 :real t :wait nil)~%")
  (warn ";; demo : walk through gait1 and telep in side of vehicle~%")
  (warn "  (all-demo-task1 :real t :wait nil :auto-walk-and-telep t)~%")
  (warn ";; demo : no walk and telep in side of vehicle~%")
  (warn "  (all-demo-task1 :real t :wait nil :no-walk-and-telep t)~%")
  )
