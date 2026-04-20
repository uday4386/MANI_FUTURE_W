export type NewsType = 'Political' | 'AndhraPradesh' | 'Telangana' | 'National' | 'International' | 'Crime' | 'Education' | 'Jobs' | 'Classifieds' | 'Live' | 'Business' | 'Sports' | 'Agriculture' | 'Marriage' | 'RealEstate' | 'Bhakthi' | 'Health' | 'Social' | 'Accident' | 'Weather' | 'Others';

export interface MarriageDetails {
    full_name?: string;
    gender?: string;
    date_of_birth?: string;
    age?: number;
    profile_photo?: string;
    location?: string;
    native_place?: string;
    religion?: string;
    caste?: string;
    sub_caste?: string;
    mother_tongue?: string;
    highest_education?: string;
    college_name?: string;
    occupation?: string;
    company_name?: string;
    annual_income?: string;
    father_name?: string;
    father_occupation?: string;
    mother_name?: string;
    mother_occupation?: string;
    siblings?: string;
    phone_number?: string;
    email?: string;
    whatsapp_number?: string;
    is_contact_visible?: boolean;
}

export interface NewsItem {
    id: string;
    title: string;
    description: string;
    imageUrl?: string;
    videoUrl?: string; // Note: In DB table this is snake_case 'video_url', we'll map it
    liveLink?: string;
    area: string;
    type: NewsType;
    isBreaking: boolean; // DB: is_breaking
    timestamp: string;
    author?: string;
    status?: 'published' | 'pending' | 'rejected';
    likes?: number;
    commentsCount?: number;
    marriageDetails?: MarriageDetails;
}

export interface ShortItem {
    id: string;
    title: string;
    videoUrl: string; // DB: video_url
    duration: number;
    timestamp: string;
    likes?: number;
    commentsCount?: number;
    area?: string;
    author?: string;
    status?: 'published' | 'pending' | 'rejected';
}

export interface Advertisement {
    id: string;
    mediaUrl: string; // DB: media_url
    intervalMinutes: number; // DB: interval_minutes
    displayInterval?: number; // DB: display_interval
    clickUrl?: string; // DB: click_url
    isActive: boolean; // DB: is_active
    status?: 'published' | 'pending' | 'rejected';
    timestamp: string;
}
